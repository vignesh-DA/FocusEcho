import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/distraction_event.dart';
import '../../core/models/focus_session.dart';
import '../../core/models/intervention_event.dart';
import '../../core/providers/app_dependencies.dart';
import '../../local_db/distraction_event_dao.dart';
import '../../local_db/focus_session_dao.dart';
import '../../local_db/intervention_event_dao.dart';
import '../../services/sync_service.dart';
import '../../services/supabase_service.dart';
import '../../services/browser_monitor/browser_monitor.dart';
import 'focus_session_state.dart';
import 'focus_detection_engine.dart';
import 'rule_engine.dart';

int medianRecoverySeconds(Iterable<Map<String, dynamic>> rows) {
  final recoveryTimes = rows
      .map((row) => row['recovery_time_seconds'])
      .whereType<num>()
      .map((value) => value.toInt())
      .toList()
    ..sort();
  if (recoveryTimes.isEmpty) return 0;
  return recoveryTimes[recoveryTimes.length ~/ 2];
}

class FocusSessionViewModel extends StateNotifier<FocusSessionState> {
  FocusSessionViewModel(this._prefs, this._sessionDao, this._eventDao,
      this._interventionDao, this._syncService,
      {SupabaseService? supabaseService})
      : _supabaseServiceOverride = supabaseService,
        _sessionChannel = const MethodChannel(AppChannels.session),
        _streamChannel = const EventChannel(AppChannels.distractionStream),
        super(const FocusSessionState()) {
    _loadAvailableApps();
    _engine.setActionHandler(_handleEngineAction);
    _listenToDistractionStream();
    if (kIsWeb) {
      unawaited(_browserMonitor.initialize().then((_) {
        if (mounted) {
          state = state.copyWith(
              extensionConnected: _browserMonitor.extensionConnected);
          if (_browserMonitor.activeExtensionSession != null) {
            _adoptExtensionSession(_browserMonitor.activeExtensionSession!);
          }
        }
      }));
      _browserSubscription =
          _browserMonitor.activities.listen(_handleBrowserActivity);
      _browserStatusSubscription =
          _browserMonitor.connectionStatus.listen((connected) {
        if (mounted) state = state.copyWith(extensionConnected: connected);
      });
      _browserSessionSubscription =
          _browserMonitor.activeSessionUpdates.listen((sessionMap) {
        if (!mounted) return;
        if (sessionMap != null) {
          _adoptExtensionSession(sessionMap);
        }
      });
    }
  }

  final SharedPreferences _prefs;
  final FocusSessionDao _sessionDao;
  final DistractionEventDao _eventDao;
  final InterventionEventDao _interventionDao;
  final SyncService _syncService;
  final SupabaseService? _supabaseServiceOverride;
  final MethodChannel _sessionChannel;
  final EventChannel _streamChannel;
  final Uuid _uuid = const Uuid();
  final FocusDetectionEngine _engine = FocusDetectionEngine();
  final BrowserMonitor _browserMonitor = BrowserMonitor.instance;
  Timer? _timer;
  StreamSubscription<dynamic>? _subscription;
  StreamSubscription? _browserSubscription;
  StreamSubscription<bool>? _browserStatusSubscription;
  StreamSubscription<Map<String, dynamic>?>? _browserSessionSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _feedSubscription;

  SupabaseService? get _supabaseService {
    if (_supabaseServiceOverride != null) return _supabaseServiceOverride;
    try {
      return AppDependencies.supabaseService;
    } catch (_) {
      return null;
    }
  }

  bool get _supabaseReady {
    final service = _supabaseService;
    if (service == null) return false;
    if (_supabaseServiceOverride != null) return true;
    try {
      return service.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  static const Set<String> _defaultAlwaysAllowed = {
    'com.android.phone',
    'com.google.android.dialer',
    'com.android.systemui',
    'com.google.android.apps.authenticator2',
    'com.microsoft.authenticator',
    'com.focusecho.ai',
  };

  static const Set<String> _defaultAllowedWithLimit = {
    'com.phonepe.app',
    'net.one97.paytm',
    'com.google.android.apps.nbu.paisa.user',
    'com.google.android.apps.docs',
    'com.microsoft.office.*',
    'com.android.chrome',
  };

  static const Set<String> _defaultAlwaysDistraction = {
    'com.instagram.android',
    'com.facebook.katana',
    'com.twitter.android',
    'com.zhiliaoapp.musically',
  };

  static const Set<String> _defaultNeutralApps = {
    'com.android.launcher',
    'com.android.launcher3',
    'com.google.android.apps.nexuslauncher',
    'com.android.settings',
  };

  void _loadAvailableApps() {
    final raw = _prefs.getString(AppKeys.productiveApps) ?? '[]';
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final apps = decoded.cast<String>().toList();
      state = state.copyWith(
        availableProductiveApps: apps,
        selectedProductiveApp: apps.isNotEmpty ? apps.first : null,
      );
    } catch (_) {
      state = state.copyWith(availableProductiveApps: const []);
    }
  }

  void selectProductiveApp(String app) {
    state = state.copyWith(selectedProductiveApp: app);
  }

  /// Feature 1 — Focus Intent. Called on every keystroke so the setup UI can
  /// enable/disable the start button live.
  void setIntent(String value) {
    state = state.copyWith(intent: value);
  }

  void _listenToDistractionStream() {
    if (kIsWeb) return;
    _subscription = _streamChannel.receiveBroadcastStream().listen((event) {
      final map = jsonDecode(event as String) as Map<String, dynamic>;
      final eventType = (map['eventType'] as String?) ?? 'app_switch';
      final timestampRaw = map['timestamp'] as String?;
      final timestamp = DateTime.tryParse(timestampRaw ?? '') ?? DateTime.now();
      final packageName = map['packageName'] as String?;
      final appLabel = map['appLabel'] as String? ?? packageName ?? 'unknown';
      // Feature 2 — escalation level computed by the native relapse ladder.
      final escalationLevel = (map['escalation_level'] as num?)?.toInt() ?? 1;

      // Feature 2 — intervention lifecycle events emitted by the native layer.
      if (eventType == 'intervention_shown' ||
          eventType == 'intervention_action') {
        unawaited(_handleNativeInterventionEvent(eventType, map));
        return;
      }

      // ADB test fixture relapses feed onDistractionDetected directly — the
      // SAME registration path real detection uses (SQLite insert, distraction
      // counter, escalation ladder). The engine's app-switch dedupe would
      // otherwise swallow repeated synthetic broadcasts (same package, no real
      // foreground change between them).
      if (map['source'] == 'adb_fixture' && packageName != null) {
        unawaited(
          onDistractionDetected(
            packageName,
            appLabel,
            escalationLevel: escalationLevel,
          ),
        );
        return;
      }

      final signal = switch (eventType) {
        'notification' => FocusSignal(
            type: FocusEventType.notification,
            timestamp: timestamp,
            packageName: packageName,
            appLabel: appLabel,
          ),
        'screen_on' => FocusSignal(
            type: FocusEventType.screenOn,
            timestamp: timestamp,
          ),
        'screen_off' => FocusSignal(
            type: FocusEventType.screenOff,
            timestamp: timestamp,
          ),
        _ => FocusSignal(
            type: FocusEventType.appSwitch,
            timestamp: timestamp,
            packageName: packageName,
            appLabel: appLabel,
            source: map['source'] as String?,
            escalationLevel: escalationLevel,
          ),
      };

      final actions = _engine.handleSignal(signal);
      for (final action in actions) {
        _handleEngineAction(action);
      }
    });
  }

  Future<void> startSession(String productiveApp, {String intent = ''}) async {
    // Feature 1 — a session cannot start without a stated intent.
    final trimmedIntent = intent.trim();
    if (trimmedIntent.isEmpty) return;

    final userId = _prefs.getString(AppKeys.userId) ?? 'local-user';
    final session = FocusSession(
      id: _uuid.v4(),
      userId: userId,
      startTime: DateTime.now(),
      productiveApp: productiveApp,
      intent: trimmedIntent,
    );
    await _sessionDao.insertSession(session);
    _requestSync();
    // Persist the intent so the native layer can show it on full-screen
    // interventions (Feature 2).
    await _prefs.setString(AppKeys.sessionIntent, trimmedIntent);
    if (!kIsWeb) {
      await _sessionChannel.invokeMethod<void>('startSession');
    }
    await _prefs.setBool(AppKeys.sessionActive, true);
    if (kIsWeb) {
      await _browserMonitor.startSession(
        _decodeStringList(
            _prefs.getString(AppKeys.webDistractingSites) ?? '[]'),
        sessionId: session.id,
        intention: trimmedIntent,
        userId: userId,
      );
    }

    _engine.reset();
    _engine.configure(_buildConfig(productiveApp));

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });

    state = state.copyWith(
      isActive: true,
      session: session,
      distractionCount: 0,
      sessionXp: 0,
      intent: trimmedIntent,
      escalationLevel: 1,
      sessionSummary: null,
      liveDistractionFeed: const [],
      sessionSummaryStats: null,
      crossSurfaceNudge: null,
    );

    // Feature 4 — subscribe to the cross-surface intervention channel.
    unawaited(_subscribeToLiveFeed(session.id));
    unawaited(_subscribeCrossSurface());
  }

  Future<void> _subscribeToLiveFeed(String sessionId) async {
    if (!_supabaseReady) return;
    final service = _supabaseService;
    if (service == null) return;
    await _feedSubscription?.cancel();
    try {
      _feedSubscription =
          service.watchDistractionEvents(sessionId).listen((rows) {
        if (mounted) {
          state = state.copyWith(
            liveDistractionFeed: List<Map<String, dynamic>>.unmodifiable(rows),
          );
        }
      });
    } catch (error) {
      debugPrint('[FocusSession] Live distraction feed unavailable: $error');
    }
  }

  void _adoptExtensionSession(Map<String, dynamic> sessionMap) {
    final sessionId = sessionMap['session_id']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;

    if (state.isActive && state.session?.id == sessionId) return;

    final intention = sessionMap['intention']?.toString() ?? 'Deep Work';
    final startedAtRaw = sessionMap['started_at'];
    DateTime startedAt;
    if (startedAtRaw is int) {
      startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtRaw);
    } else if (startedAtRaw is String) {
      startedAt = DateTime.tryParse(startedAtRaw) ?? DateTime.now();
    } else {
      startedAt = DateTime.now();
    }

    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final distractionCount =
        (sessionMap['distraction_count'] as num?)?.toInt() ?? 0;
    final userId = _prefs.getString(AppKeys.userId) ?? 'local-user';

    final session = FocusSession(
      id: sessionId,
      userId: userId,
      startTime: startedAt,
      productiveApp: 'Chrome',
      intent: intention,
      totalDistractions: distractionCount,
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
      }
    });

    final level = (distractionCount <= 1)
        ? 1
        : (distractionCount <= 3 ? 2 : 3);

    state = state.copyWith(
      isActive: true,
      session: session,
      intent: intention,
      selectedProductiveApp: 'Chrome',
      elapsedSeconds: elapsed >= 0 ? elapsed : 0,
      distractionCount: distractionCount,
      escalationLevel: level,
      sessionSummary: null,
      liveDistractionFeed: const [],
    );

    unawaited(_subscribeToLiveFeed(sessionId));
  }
  // ── MOB-3b — Session Resume on App Relaunch ──────────────────────────────

  /// Called by [SplashScreen._goNext] when it detects [AppKeys.sessionActive]
  /// is true. Reads the in-progress session row from SQLite, rebuilds the
  /// engine config, and restarts the elapsed-second timer so the UI shows the
  /// correct running duration even after a process kill.
  ///
  /// Returns true when a session was successfully resumed, false if no active
  /// session exists in the database (allows caller to fall back to dashboard).
  Future<bool> resumeSession() async {
    // Skip on web — web sessions don't survive full page reloads.
    if (kIsWeb) return false;

    final session = await _sessionDao.getActiveSession();
    if (session == null) {
      // Pref flag was stale — clean it up so we don't loop.
      await _prefs.setBool(AppKeys.sessionActive, false);
      debugPrint(
          '[FocusSession] resumeSession: no active SQLite row found; cleared stale flag.');
      return false;
    }

    // Compute how many seconds have elapsed since the session started,
    // accounting for the time the process was dead.
    final alreadyElapsed =
        DateTime.now().difference(session.startTime).inSeconds;

    _engine.reset();
    _engine.configure(_buildConfig(session.productiveApp));

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });

    state = state.copyWith(
      isActive: true,
      session: session,
      elapsedSeconds: alreadyElapsed,
      distractionCount: 0,
      sessionXp: 0,
      intent: session.intent,
      escalationLevel: 1,
      sessionSummary: null,
      liveDistractionFeed: const [],
      sessionSummaryStats: null,
      crossSurfaceNudge: null,
    );

    debugPrint(
      '[FocusSession] Resumed session ${session.id} '
      '(${session.productiveApp}, already ${alreadyElapsed}s elapsed).',
    );

    unawaited(_subscribeToLiveFeed(session.id));
    unawaited(_subscribeCrossSurface());
    return true;
  }

  /// Test-only distraction fixture — bypasses all DAO/SQLite calls that are
  /// unavailable on the web platform.  The event is tagged with
  /// The test fixture event is kept out of production analytics
  /// analytics.  The distraction counter and escalation ladder still fire
  /// exactly as they do on mobile, making this a valid smoke target for
  /// TC_DISTRACT_001–006.
  ///
  /// NOTE (TC_DISTRACT_006): This method is the ONLY way a simulated event can
  /// enter the state machine.  It does NOT call [onDistractionDetected] and
  /// does NOT touch [FocusDetectionEngine] or the native EventChannel — it
  /// cannot be confused with real detection coverage.
  @visibleForTesting
  Future<void> simulateWebDistraction(
      String packageName, String appLabel) async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    // Compute escalation level the same way native does, so the test fixture
    // ladder mirrors the real escalation ladder exactly.
    final level = _levelForRelapse(state.distractionCount + 1);

    final event = DistractionEvent(
      id: _uuid.v4(),
      sessionId: sessionId,
      packageName: packageName,
      appLabel: appLabel,
      triggeredAt: DateTime.now(),
      riskScore: 'MEDIUM',
      riskScoreNumeric: 0.4,
      eventType: 'test_fixture',
      escalationLevel: level,
    );

    await _registerDistraction(event);
  }

  Future<void> onDistractionDetected(
    String packageName,
    String appLabel, {
    int escalationLevel = 1,
  }) async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    final recent =
        await _eventDao.getRecentEvents(30, eventType: 'distraction');
    final distractionsInWindow = recent.length;
    final riskScore = RuleEngine.computeRiskScore(
      category: AppCategory.unknown,
      timeAwaySeconds: 0,
      distractionsInLast30Min: distractionsInWindow,
      returnedToFocus: false,
    );
    final risk = RuleEngine.riskLabel(riskScore);
    final event = DistractionEvent(
      id: _uuid.v4(),
      sessionId: sessionId,
      packageName: packageName,
      appLabel: appLabel,
      triggeredAt: DateTime.now(),
      riskScore: risk,
      riskScoreNumeric: riskScore,
      escalationLevel: escalationLevel,
    );
    await _eventDao.insertEvent(event);
    await _registerDistraction(event);
  }

  /// Shared escalation path for both native and browser distractions.
  ///
  /// [C1 fix] Escalation level source-of-truth:
  ///   - For native events (usage_stats / adb_fixture): [event.escalationLevel]
  ///     is set from the Kotlin payload which already ran through
  ///     [DistractionEventQueue.registerRelapse()] + [escalationLevelFor()].
  ///     Flutter trusts that value directly — no recomputation.
  ///   - For web / simulation (escalationLevel == 1 at default AND
  ///     distractionCount > 0): Flutter's own [_levelForRelapse] is used as a
  ///     fallback so the test fixture escalation ladder still works.
  Future<void> _registerDistraction(DistractionEvent event) async {
    final newCount = state.distractionCount + 1;
    // Use the native-computed level when present; fall back to local computation
    // only for test fixture / simulation (where native layer never runs).
    final level = (event.escalationLevel > 1)
        ? event.escalationLevel
        : _levelForRelapse(newCount);
    debugPrint(
      '[FocusSession] distraction #$newCount '
      'native_level=${event.escalationLevel} '
      'resolved_level=$level '
      'source=${event.eventType}',
    );
    state = state.copyWith(
      distractionCount: newCount,
      currentRiskScore: event.riskScore,
      showAlert: true,
      lastDistractionPackage: event.packageName,
      lastDistractionLabel: event.appLabel,
      lastEventId: event.id,
      escalationLevel: level,
    );
    await _logIntervention(level, 'shown');
    unawaited(_broadcastDistraction(event, level));
  }

  /// Escalation ladder (Feature 2):
  /// relapse 1 -> level 1 (heads-up), relapse 2-3 -> level 2 (full-screen),
  /// relapse 4+ -> level 3 (forced choice, no dismiss-and-ignore).
  int _levelForRelapse(int relapseCount) {
    if (relapseCount <= 1) return 1;
    if (relapseCount <= 3) return 2;
    return 3;
  }

  Future<void> onRecovery(String eventId,
      {bool returnedToOrigin = false, int? timeAwaySeconds}) async {
    try {
      final events =
          await _eventDao.getEventsForSession(state.session?.id ?? '');
      final event = events.where((e) => e.id == eventId).firstOrNull;
      if (event == null) {
        debugPrint('Recovery event $eventId not found, dismissing alert.');
        state = state.copyWith(showAlert: false);
        return;
      }
      final seconds = timeAwaySeconds ??
          DateTime.now().difference(event.triggeredAt).inSeconds;
      await _eventDao.updateRecovery(
        eventId,
        DateTime.now(),
        seconds,
        returnedToOrigin: returnedToOrigin,
      );
      // Feature 3 — the recovered row must be re-pushed so Supabase gets the
      // returned_at (recovered_at) backfill even if the original event was
      // already synced before the user returned.
      await _eventDao.markAsUnsynced(eventId);
      final gained = seconds < AppRiskThresholds.mediumRecoverySeconds
          ? AppXP.recoveryXp
          : AppXP.slowRecoveryXp;
      state =
          state.copyWith(sessionXp: state.sessionXp + gained, showAlert: false);
      unawaited(_syncService.syncPendingEvents());
    } catch (e) {
      debugPrint('Error during recovery: $e');
      state = state.copyWith(showAlert: false);
    }
  }

  Future<void> stopSession() async {
    final session = state.session;
    if (session == null) return;
    _timer?.cancel();
    final feed =
        List<Map<String, dynamic>>.unmodifiable(state.liveDistractionFeed);
    await _feedSubscription?.cancel();
    _feedSubscription = null;
    final minutes = state.elapsedSeconds ~/ 60;
    final events = await _eventDao.getEventsForSession(session.id);
    final distractionEvents =
        events.where((e) => e.eventType == 'distraction').toList();
    final totalDistractions = distractionEvents.length;
    final avgRecoverySeconds = distractionEvents.isEmpty
        ? 0.0
        : distractionEvents
                .map((e) => e.recoveryTimeSeconds ?? 0)
                .reduce((a, b) => a + b) /
            distractionEvents.length;
    final criticalDistractions =
        distractionEvents.where((e) => e.riskScore == 'CRITICAL').length;
    final focusScore = RuleEngine.computeFocusScore(
      totalDistractions: totalDistractions,
      sessionMinutes: minutes,
      avgRecoverySeconds: avgRecoverySeconds,
      criticalDistractions: criticalDistractions,
    );

    // MOB-3e — Award base completion XP for sessions that reached the minimum
    // duration threshold. Recovery XP is already accumulated in state.sessionXp
    // throughout the session; we add the flat completion bonus on top here so
    // the final row stored in SQLite always contains the complete earned total.
    var finalSessionXp = state.sessionXp;
    if (minutes >= AppXP.minSessionMinutesForXp) {
      finalSessionXp += AppXP.sessionCompletionXp;
      debugPrint(
        '[FocusSession] Awarded ${AppXP.sessionCompletionXp} completion XP '
        '(session ${session.id}, ${minutes}min). '
        'Total session XP: $finalSessionXp',
      );
    }

    await _sessionDao.updateSessionEnd(
      session.id,
      DateTime.now(),
      totalDistractions,
      finalSessionXp,
      focusScore,
      SessionStatus.completed.name,
    );
    if (!kIsWeb) {
      await _sessionChannel.invokeMethod<void>('stopSession');
    } else {
      await _browserMonitor.stopSession();
    }
    _requestSync();
    await _prefs.setBool(AppKeys.sessionActive, false);
    await _prefs.remove(AppKeys.sessionIntent);

    // MOB-3f — Wire updateUserXP: accumulate running lifetime XP in prefs
    // (offline-safe source of truth), then push to Supabase when signed in.
    final prevTotalXp = _prefs.getInt(AppKeys.xpTotal) ?? 0;
    final newTotalXp = prevTotalXp + finalSessionXp;
    await _prefs.setInt(AppKeys.xpTotal, newTotalXp);

    // MOB-3c/3d — Update streak counters. Must run after XP so the Supabase
    // push carries the already-updated streak value.
    final newStreakDays = await _updateStreak();

    debugPrint(
      '[FocusSession] Updated local XP: $prevTotalXp -> $newTotalXp '
      '(streak: $newStreakDays days)',
    );
    final userId = _prefs.getString(AppKeys.userId);
    if (userId != null && userId.isNotEmpty) {
      try {
        unawaited(
          AppDependencies.supabaseService
              .updateUserXP(userId, newTotalXp, newStreakDays)
              .catchError((Object e) {
            debugPrint(
                '[FocusSession] updateUserXP remote sync failed (will retry on next sync): $e');
          }),
        );
      } catch (e) {
        debugPrint('[FocusSession] updateUserXP unavailable: $e');
      }
    }

    unawaited(_syncService.syncPendingEvents());
    _unsubscribeCrossSurface();
    _engine.reset();

    // Feature 1 — keep the completed session around so the session-complete
    // view can render intent + planned vs. actual duration.
    state = state.copyWith(
      isActive: false,
      sessionSummaryStats: {
        'duration_seconds': state.elapsedSeconds,
        'distraction_count': state.distractionCount,
        'median_recovery_seconds': medianRecoverySeconds(feed),
        'focus_score': focusScore,
        'session_xp': finalSessionXp,
        'started_at': session.startTime.toIso8601String(),
        'feed_snapshot': feed,
      },
      liveDistractionFeed: feed,
      sessionSummary: SessionSummary(
        sessionId: session.id,
        intent: session.intent,
        productiveApp: session.productiveApp,
        actualSeconds: state.elapsedSeconds,
        totalDistractions: totalDistractions,
        sessionXp: finalSessionXp,
        focusScore: focusScore,
      ),
      showAlert: false,
    );
    _loadAvailableApps(); // Reload for next session
  }

  // ── MOB-3c / MOB-3d — Streak Update ────────────────────────────────────

  /// Computes and persists the updated consecutive streak and lifetime
  /// cumulative streak counters after a session is completed.
  ///
  /// Rules (MOB-3c):
  ///   - A session must be ≥ [AppXP.minSessionMinutesForXp] minutes to count
  ///     toward the streak (same guard as XP, keeps the two in sync).
  ///   - If the last completed session was on the SAME calendar day, the streak
  ///     count does not increment again (prevents multiple sessions one day from
  ///     double-counting).
  ///   - If the gap since the last session date is within [AppDurations.streakGraceDays]
  ///     missed calendar days the current streak is extended.
  ///   - Otherwise the streak resets to 1.
  ///
  /// Rule (MOB-3d):
  ///   - [AppKeys.cumulativeStreakDays] always increments by 1 for each
  ///     qualifying session regardless of streak resets.
  ///
  /// Returns the new consecutive streak value so the caller can push it to
  /// Supabase in the same [stopSession] call.
  Future<int> _updateStreak() async {
    final minutes = state.elapsedSeconds ~/ 60;
    if (minutes < AppXP.minSessionMinutesForXp) {
      // Session too short — do not touch streak counters.
      return _prefs.getInt(AppKeys.streakDays) ?? 0;
    }

    final today = DateTime.now();
    final todayLabel =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final lastDateRaw = _prefs.getString(AppKeys.lastSessionDate);
    var currentStreak = _prefs.getInt(AppKeys.streakDays) ?? 0;

    if (lastDateRaw != null) {
      final lastDate = DateTime.tryParse(lastDateRaw);
      if (lastDate != null) {
        // Strip time component: compare calendar-day difference only.
        final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final todayDay = DateTime(today.year, today.month, today.day);
        final gapDays = todayDay.difference(lastDay).inDays;

        if (gapDays == 0) {
          // Same calendar day — already counted; do not increment streak.
          debugPrint(
              '[Streak] Same day session — streak unchanged at $currentStreak.');
          return currentStreak;
        } else if (gapDays <= 1 + AppDurations.streakGraceDays) {
          // Yesterday or within grace window — extend streak.
          currentStreak += 1;
        } else {
          // Too many missed days — reset.
          debugPrint(
              '[Streak] Gap of $gapDays days exceeds grace. Resetting streak.');
          currentStreak = 1;
        }
      } else {
        currentStreak = 1; // Corrupt stored date — start fresh.
      }
    } else {
      // First ever session.
      currentStreak = 1;
    }

    // MOB-3d — lifetime cumulative counter.
    final prevCumulative = _prefs.getInt(AppKeys.cumulativeStreakDays) ?? 0;
    final newCumulative = prevCumulative + 1;

    await _prefs.setInt(AppKeys.streakDays, currentStreak);
    await _prefs.setInt(AppKeys.cumulativeStreakDays, newCumulative);
    await _prefs.setString(AppKeys.lastSessionDate, todayLabel);

    debugPrint(
      '[Streak] consecutive=$currentStreak cumulative=$newCumulative '
      'lastDate=$todayLabel',
    );
    return currentStreak;
  }

  /// Dismisses the session-complete summary and returns to the setup view.
  void dismissSummary() {
    state = FocusSessionState(
      availableProductiveApps: state.availableProductiveApps,
      selectedProductiveApp: state.selectedProductiveApp,
    );
  }

  void dismissAlert() => state = state.copyWith(showAlert: false);

  void snoozeApp(String packageName) {
    _engine.snooze(packageName, 5); // 5 minutes snooze
    state = state.copyWith(showAlert: false);
    unawaited(_logIntervention(state.escalationLevel, 'snoozed'));
  }

  /// Feature 2 — user chose "Return to Focus" on an intervention.
  void returnToFocusFromIntervention() {
    state = state.copyWith(showAlert: false);
    unawaited(_logIntervention(state.escalationLevel, 'return_to_focus'));
  }

  /// Feature 2 — user chose "Take a Break" (level 2-3 full-screen alert).
  void takeBreakFromIntervention() {
    state = state.copyWith(showAlert: false);
    unawaited(_logIntervention(state.escalationLevel, 'take_break'));
  }

  /// Feature 2 — user chose "Pause Session" (level 3+ forced choice).
  Future<void> pauseSessionFromIntervention() async {
    unawaited(_logIntervention(state.escalationLevel, 'pause_session'));
    await stopSession();
  }

  /// Logs an intervention row (Feature 2). [actionTaken] is one of:
  /// shown | dismissed | return_to_focus | take_break | pause_session | snoozed
  Future<void> _logIntervention(int level, String actionTaken) async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;
    final event = InterventionEvent(
      id: _uuid.v4(),
      sessionId: sessionId,
      level: level,
      actionTaken: actionTaken,
      timestamp: DateTime.now(),
    );
    try {
      await _interventionDao.insertEvent(event);
    } catch (e) {
      debugPrint('Failed to log intervention: $e');
    }
  }

  /// Handles intervention lifecycle events forwarded by the native layer
  /// (full-screen InterventionActivity shown / button pressed).
  Future<void> _handleNativeInterventionEvent(
      String eventType, Map<String, dynamic> map) async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;
    final level = (map['level'] as num?)?.toInt() ?? 1;
    final action = eventType == 'intervention_shown'
        ? 'shown'
        : (map['action'] as String?) ?? 'dismissed';
    final event = InterventionEvent(
      id: _uuid.v4(),
      sessionId: sessionId,
      level: level,
      actionTaken: action,
      timestamp: DateTime.now(),
    );
    try {
      await _interventionDao.insertEvent(event);
    } catch (e) {
      debugPrint('Failed to log native intervention: $e');
    }
    if (eventType == 'intervention_action') {
      if (action == 'pause_session') {
        await stopSession();
      } else if (action == 'return_to_focus') {
        state = state.copyWith(showAlert: false);
      } else if (action == 'take_break') {
        await _pauseSessionForBreak();
      }
    }
  }

  /// Feature 2 — "Take a Break" pauses the active session: the timer and the
  /// native detection service stop, and the UI returns to the setup view.
  /// The session row is intentionally left open (no end_time, status stays
  /// 'active') so a future resume feature can continue the same session.
  Future<void> _pauseSessionForBreak() async {
    if (!state.isActive) return;
    _timer?.cancel();
    state = state.copyWith(showAlert: false, isActive: false);
    if (!kIsWeb) {
      try {
        await _sessionChannel.invokeMethod<void>('stopSession');
      } catch (e) {
        debugPrint('Failed to stop native detection on break: $e');
      }
    }
    await _prefs.setBool(AppKeys.sessionActive, false);
  }

  FocusDetectionConfig _buildConfig(String focusApp) {
    final productiveRaw = _prefs.getString(AppKeys.productiveApps) ?? '[]';
    final distractingRaw = _prefs.getString(AppKeys.distractingApps) ?? '[]';
    final limitsRaw = _prefs.getString(AppKeys.appTimeLimitsSeconds) ?? '{}';

    final productiveApps = _decodeStringList(productiveRaw);
    final distractingApps = _decodeStringList(distractingRaw);
    final timeLimits = _decodeIntMap(limitsRaw);

    final alwaysAllowed = {
      ..._defaultAlwaysAllowed,
      ...productiveApps,
      focusApp
    };
    final alwaysDistraction = {
      ..._defaultAlwaysDistraction,
      ...distractingApps
    };

    return FocusDetectionConfig(
      focusApp: focusApp,
      alwaysAllowedApps: alwaysAllowed,
      allowedWithLimitApps: _defaultAllowedWithLimit,
      alwaysDistractionApps: alwaysDistraction,
      neutralApps: _defaultNeutralApps,
      timeLimitsSeconds: timeLimits,
      gracePeriodMs: AppDurations.gracePeriodMs,
      transitionThresholdMs: AppDurations.transitionThresholdMs,
      unknownThresholdMs: AppDurations.unknownThresholdMs,
      notificationGraceMs: AppDurations.notificationGraceMs,
      screenOnGraceMs: AppDurations.screenOnGraceMs,
      debounceMs: AppDurations.debounceMs,
    );
  }

  List<String> _decodeStringList(String raw) {
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, int> _decodeIntMap(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
    } catch (_) {
      return const {};
    }
  }

  Future<void> _handleBrowserActivity(BrowserActivity activity) async {
    if (!state.isActive) return;
    final kind = activity.kind;
    if (kind == 'distraction') {
      await onDistractionDetected('web:${activity.host}', activity.host);
    } else if (kind == 'return' &&
        state.showAlert &&
        state.lastEventId != null) {
      await onRecovery(state.lastEventId!, returnedToOrigin: true);
    }
  }

  Future<void> _handleEngineAction(FocusAction action) async {
    switch (action.type) {
      case FocusActionType.distractionTriggered:
        await _logDistraction(action.payload);
        break;
      case FocusActionType.intentionalSwitch:
        await _logIntentionalSwitch(action.payload);
        break;
      case FocusActionType.recovery:
        final eventId = state.lastEventId;
        if (eventId != null) {
          final timeAway = action.payload['timeAwaySeconds'] as int? ?? 0;
          await onRecovery(eventId,
              returnedToOrigin: true, timeAwaySeconds: timeAway);
        }
        break;
    }
  }

  Future<void> _logDistraction(Map<String, dynamic> payload) async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    final packageName = payload['packageName'] as String? ?? 'unknown';
    final category = payload['category'] as AppCategory? ?? AppCategory.unknown;
    final timeAwaySeconds = payload['timeAwaySeconds'] as int? ?? 0;
    final wasNotificationTriggered =
        payload['wasNotificationTriggered'] as bool? ?? false;
    final returnedToOrigin = payload['returnedToOrigin'] as bool? ?? false;
    final switchStackDepth = payload['switchStackDepth'] as int? ?? 0;
    final timestamp = payload['timestamp'] as DateTime? ?? DateTime.now();
    // Feature 2 — escalation level attached by the native relapse ladder
    // (adb_fixture / usage_stats payloads); engine-only paths default to 1.
    final escalationLevel = payload['escalation_level'] as int? ?? 1;

    final recent =
        await _eventDao.getRecentEvents(30, eventType: 'distraction');
    final riskScore = RuleEngine.computeRiskScore(
      category: category,
      timeAwaySeconds: timeAwaySeconds,
      distractionsInLast30Min: recent.length,
      returnedToFocus: returnedToOrigin,
    );
    final risk = RuleEngine.riskLabel(riskScore);

    final now = DateTime.now();
    final event = DistractionEvent(
      id: _uuid.v4(),
      sessionId: sessionId,
      packageName: packageName,
      appLabel: payload['appLabel'] as String? ?? packageName,
      triggeredAt: timestamp,
      riskScore: risk,
      eventType: 'distraction',
      appCategory: _categoryLabel(category),
      timeAwaySeconds: timeAwaySeconds,
      riskScoreNumeric: riskScore,
      wasNotificationTriggered: wasNotificationTriggered,
      returnedToOrigin: returnedToOrigin,
      switchStackDepth: switchStackDepth,
      timeOfDayHour: now.hour,
      dayOfWeek: now.weekday,
      sessionMinuteWhenOccurred: state.elapsedSeconds ~/ 60,
      escalationLevel: escalationLevel,
    );

    await _eventDao.insertEvent(event);
    await _registerDistraction(event);
  }

  Future<void> _logIntentionalSwitch(Map<String, dynamic> payload) async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    final packageName = payload['packageName'] as String? ?? 'unknown';
    final category = payload['category'] as AppCategory? ?? AppCategory.unknown;
    final timeAwaySeconds = payload['timeAwaySeconds'] as int? ?? 0;
    final wasNotificationTriggered =
        payload['wasNotificationTriggered'] as bool? ?? false;
    final returnedToOrigin = payload['returnedToOrigin'] as bool? ?? true;
    final switchStackDepth = payload['switchStackDepth'] as int? ?? 0;
    final timestamp = payload['timestamp'] as DateTime? ?? DateTime.now();

    final now = DateTime.now();
    final event = DistractionEvent(
      id: _uuid.v4(),
      sessionId: sessionId,
      packageName: packageName,
      appLabel: payload['appLabel'] as String? ?? packageName,
      triggeredAt: timestamp,
      riskScore: 'SAFE',
      eventType: 'intentional',
      appCategory: _categoryLabel(category),
      timeAwaySeconds: timeAwaySeconds,
      riskScoreNumeric: 0,
      wasNotificationTriggered: wasNotificationTriggered,
      returnedToOrigin: returnedToOrigin,
      switchStackDepth: switchStackDepth,
      timeOfDayHour: now.hour,
      dayOfWeek: now.weekday,
      sessionMinuteWhenOccurred: state.elapsedSeconds ~/ 60,
    );

    await _eventDao.insertEvent(event);
  }

  String _categoryLabel(AppCategory category) {
    return switch (category) {
      AppCategory.alwaysAllowed => 'always_allowed',
      AppCategory.allowedWithLimit => 'allowed_with_limit',
      AppCategory.alwaysDistraction => 'always_distraction',
      AppCategory.neutral => 'neutral',
      AppCategory.unknown => 'unknown',
    };
  }

  // ── Feature 4 — Cross-Surface Intervention Sync ──────────────────────────

  bool get _crossSurfaceEnabled =>
      (_prefs.getBool(AppKeys.crossSurfaceNudges) ?? false) &&
      AppDependencies.supabaseService.currentUser != null;

  Future<void> _subscribeCrossSurface() async {
    if (!_crossSurfaceEnabled) return;
    final userId = AppDependencies.supabaseService.currentUser?.id;
    if (userId == null) return;
    await AppDependencies.supabaseService.subscribeToInterventions(
      userId,
      (surface, label, level) {
        if (!state.isActive || !mounted) return;
        state = state.copyWith(
          crossSurfaceNudge:
              'You opened $label on your $surface — session still active.',
        );
      },
    );
  }

  void _unsubscribeCrossSurface() {
    AppDependencies.supabaseService.unsubscribeFromInterventions();
  }

  Future<void> _broadcastDistraction(DistractionEvent event, int level) async {
    if (!_crossSurfaceEnabled) return;
    final userId = AppDependencies.supabaseService.currentUser?.id;
    if (userId == null) return;
    const surface = kIsWeb ? 'browser' : 'phone';
    try {
      await AppDependencies.supabaseService.broadcastDistraction(
        userId,
        surface: surface,
        label: event.appLabel,
        level: level,
      );
    } catch (e) {
      debugPrint('Cross-surface broadcast failed: $e');
    }
  }

  /// Clears the currently displayed cross-surface nudge.
  void clearCrossSurfaceNudge() {
    state = state.copyWith(crossSurfaceNudge: null);
  }

  void _requestSync() {
    try {
      final future = _syncService.syncNow();
      unawaited(future.then<void>((_) {}, onError: (_, __) {}));
    } catch (_) {
      // Test doubles and offline adapters may not implement remote sync.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _browserSubscription?.cancel();
    _browserStatusSubscription?.cancel();
    _browserSessionSubscription?.cancel();
    _feedSubscription?.cancel();
    _unsubscribeCrossSurface();
    super.dispose();
  }
}

final focusSessionProvider =
    StateNotifierProvider<FocusSessionViewModel, FocusSessionState>(
  (ref) => FocusSessionViewModel(
    AppDependencies.prefs,
    AppDependencies.sessionDao,
    AppDependencies.eventDao,
    AppDependencies.interventionDao,
    AppDependencies.syncService,
  ),
);
