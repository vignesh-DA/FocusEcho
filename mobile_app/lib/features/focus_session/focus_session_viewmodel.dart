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
import '../../services/browser_monitor/browser_monitor.dart';
import 'focus_session_state.dart';
import 'focus_detection_engine.dart';
import 'rule_engine.dart';

class FocusSessionViewModel extends StateNotifier<FocusSessionState> {
  FocusSessionViewModel(
    this._prefs,
    this._sessionDao,
    this._eventDao,
    this._interventionDao,
    this._syncService,
  )   : _sessionChannel = const MethodChannel(AppChannels.session),
        _streamChannel = const EventChannel(AppChannels.distractionStream),
        super(const FocusSessionState()) {
    _loadAvailableApps();
    _engine.setActionHandler(_handleEngineAction);
    _listenToDistractionStream();
    if (kIsWeb) {
      unawaited(_browserMonitor.initialize());
      _browserSubscription = _browserMonitor.activities.listen(_handleBrowserActivity);
    }
  }

  final SharedPreferences _prefs;
  final FocusSessionDao _sessionDao;
  final DistractionEventDao _eventDao;
  final InterventionEventDao _interventionDao;
  final SyncService _syncService;
  final MethodChannel _sessionChannel;
  final EventChannel _streamChannel;
  final Uuid _uuid = const Uuid();
  final FocusDetectionEngine _engine = FocusDetectionEngine();
  final BrowserMonitor _browserMonitor = BrowserMonitor.instance;
  Timer? _timer;
  StreamSubscription<dynamic>? _subscription;
  StreamSubscription? _browserSubscription;

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

      // Feature 2 — intervention lifecycle events emitted by the native layer.
      if (eventType == 'intervention_shown' || eventType == 'intervention_action') {
        unawaited(_handleNativeInterventionEvent(eventType, map));
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

    var userId = _prefs.getString(AppKeys.userId) ?? _prefs.getString(AppKeys.deviceId);
    if (userId == null || userId.isEmpty) {
      userId = _uuid.v4();
      await _prefs.setString(AppKeys.deviceId, userId);
      await _prefs.setString(AppKeys.userId, userId);
    }
    final session = FocusSession(
      id: _uuid.v4(),
      userId: userId,
      startTime: DateTime.now(),
      productiveApp: productiveApp,
      intent: trimmedIntent,
    );
    await _sessionDao.insertSession(session);
    // Persist the intent so the native layer can show it on full-screen
    // interventions (Feature 2).
    await _prefs.setString(AppKeys.sessionIntent, trimmedIntent);
    if (!kIsWeb) {
      await _sessionChannel.invokeMethod<void>('startSession');
    }
    await _prefs.setBool(AppKeys.sessionActive, true);
    if (kIsWeb) {
      await _browserMonitor.startSession(
        _decodeStringList(_prefs.getString(AppKeys.webDistractingSites) ?? '[]'),
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
      crossSurfaceNudge: null,
    );

    // Feature 4 — subscribe to the cross-surface intervention channel.
    unawaited(_subscribeCrossSurface());
  }

  Future<void> onDistractionDetected(String packageName, String appLabel) async {
    final sessionId = state.session?.id;
    if (sessionId == null) return;

    final recent = await _eventDao.getRecentEvents(30, eventType: 'distraction');
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
    );
    await _eventDao.insertEvent(event);
    await _registerDistraction(event);
  }

  /// Shared escalation path for both native and browser distractions.
  /// Computes the relapse level for this session, updates state, logs the
  /// intervention as shown, and broadcasts cross-surface (Feature 4).
  Future<void> _registerDistraction(DistractionEvent event) async {
    final newCount = state.distractionCount + 1;
    final level = _levelForRelapse(newCount);
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

  Future<void> onRecovery(String eventId, {bool returnedToOrigin = false, int? timeAwaySeconds}) async {
    try {
      final events = await _eventDao.getEventsForSession(state.session?.id ?? '');
      final event = events.where((e) => e.id == eventId).firstOrNull;
      if (event == null) {
        debugPrint('Recovery event $eventId not found, dismissing alert.');
        state = state.copyWith(showAlert: false);
        return;
      }
      final seconds = timeAwaySeconds ?? DateTime.now().difference(event.triggeredAt).inSeconds;
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
      final gained = seconds < 10 ? AppXP.recoveryXp : 10;
      state = state.copyWith(sessionXp: state.sessionXp + gained, showAlert: false);
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
    final minutes = state.elapsedSeconds ~/ 60;
    final events = await _eventDao.getEventsForSession(session.id);
    final distractionEvents = events.where((e) => e.eventType == 'distraction').toList();
    final totalDistractions = distractionEvents.length;
    final avgRecoverySeconds = distractionEvents.isEmpty
        ? 0.0
        : distractionEvents
                .map((e) => e.recoveryTimeSeconds ?? 0)
                .reduce((a, b) => a + b) /
            distractionEvents.length;
    final criticalDistractions = distractionEvents.where((e) => e.riskScore == 'CRITICAL').length;
    final focusScore = RuleEngine.computeFocusScore(
      totalDistractions: totalDistractions,
      sessionMinutes: minutes,
      avgRecoverySeconds: avgRecoverySeconds,
      criticalDistractions: criticalDistractions,
    );
    await _sessionDao.updateSessionEnd(
      session.id,
      DateTime.now(),
      totalDistractions,
      state.sessionXp,
      focusScore,
      SessionStatus.completed.name,
    );
    if (!kIsWeb) {
      await _sessionChannel.invokeMethod<void>('stopSession');
    } else {
      await _browserMonitor.stopSession();
    }
    await _prefs.setBool(AppKeys.sessionActive, false);
    await _prefs.remove(AppKeys.sessionIntent);
    unawaited(_syncService.syncPendingEvents());
    _unsubscribeCrossSurface();
    _engine.reset();
    // Feature 1 — keep the completed session around so the session-complete
    // view can render intent + planned vs. actual duration.
    state = state.copyWith(
      isActive: false,
      sessionSummary: SessionSummary(
        sessionId: session.id,
        intent: session.intent,
        productiveApp: session.productiveApp,
        actualSeconds: state.elapsedSeconds,
        totalDistractions: totalDistractions,
        sessionXp: state.sessionXp,
        focusScore: focusScore,
      ),
      showAlert: false,
    );
    _loadAvailableApps(); // Reload for next session
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
  Future<void> _handleNativeInterventionEvent(String eventType, Map<String, dynamic> map) async {
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
      } else if (action == 'return_to_focus' || action == 'take_break') {
        state = state.copyWith(showAlert: false);
      }
    }
  }

  FocusDetectionConfig _buildConfig(String focusApp) {
    final productiveRaw = _prefs.getString(AppKeys.productiveApps) ?? '[]';
    final distractingRaw = _prefs.getString(AppKeys.distractingApps) ?? '[]';
    final limitsRaw = _prefs.getString(AppKeys.appTimeLimitsSeconds) ?? '{}';

    final productiveApps = _decodeStringList(productiveRaw);
    final distractingApps = _decodeStringList(distractingRaw);
    final timeLimits = _decodeIntMap(limitsRaw);

    final alwaysAllowed = {..._defaultAlwaysAllowed, ...productiveApps, focusApp};
    final alwaysDistraction = {..._defaultAlwaysDistraction, ...distractingApps};

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
      return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
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
    } else if (kind == 'return' && state.showAlert && state.lastEventId != null) {
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
          await onRecovery(eventId, returnedToOrigin: true, timeAwaySeconds: timeAway);
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
    final wasNotificationTriggered = payload['wasNotificationTriggered'] as bool? ?? false;
    final returnedToOrigin = payload['returnedToOrigin'] as bool? ?? false;
    final switchStackDepth = payload['switchStackDepth'] as int? ?? 0;
    final timestamp = payload['timestamp'] as DateTime? ?? DateTime.now();

    final recent = await _eventDao.getRecentEvents(30, eventType: 'distraction');
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
    final wasNotificationTriggered = payload['wasNotificationTriggered'] as bool? ?? false;
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
          crossSurfaceNudge: 'You opened $label on your $surface — session still active.',
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

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _browserSubscription?.cancel();
    _unsubscribeCrossSurface();
    super.dispose();
  }
}

final focusSessionProvider = StateNotifierProvider<FocusSessionViewModel, FocusSessionState>(
  (ref) => FocusSessionViewModel(
    AppDependencies.prefs,
    AppDependencies.sessionDao,
    AppDependencies.eventDao,
    AppDependencies.interventionDao,
    AppDependencies.syncService,
  ),
);