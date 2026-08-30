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
import '../../core/providers/app_dependencies.dart';
import '../../local_db/distraction_event_dao.dart';
import '../../local_db/focus_session_dao.dart';
import '../../services/sync_service.dart';
import '../../services/browser_monitor/browser_monitor.dart';
import 'focus_session_state.dart';
import 'focus_detection_engine.dart';
import 'rule_engine.dart';

class FocusSessionViewModel extends StateNotifier<FocusSessionState> {
  FocusSessionViewModel(this._prefs, this._sessionDao, this._eventDao, this._syncService)
      : _sessionChannel = const MethodChannel(AppChannels.session),
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

  void _listenToDistractionStream() {
    if (kIsWeb) return;
    _subscription = _streamChannel.receiveBroadcastStream().listen((event) {
      final map = jsonDecode(event as String) as Map<String, dynamic>;
      final eventType = (map['eventType'] as String?) ?? 'app_switch';
      final timestampRaw = map['timestamp'] as String?;
      final timestamp = DateTime.tryParse(timestampRaw ?? '') ?? DateTime.now();
      final packageName = map['packageName'] as String?;
      final appLabel = map['appLabel'] as String? ?? packageName ?? 'unknown';

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

  Future<void> startSession(String productiveApp) async {
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
    );
    await _sessionDao.insertSession(session);
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

    state = state.copyWith(isActive: true, session: session, distractionCount: 0, sessionXp: 0);
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
    state = state.copyWith(
      distractionCount: state.distractionCount + 1,
      currentRiskScore: risk,
      showAlert: true,
      lastDistractionPackage: packageName,
      lastDistractionLabel: appLabel,
      lastEventId: event.id,
    );
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
      final gained = seconds < 10 ? AppXP.recoveryXp : 10;
      state = state.copyWith(sessionXp: state.sessionXp + gained, showAlert: false);
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
    unawaited(_syncService.syncPendingEvents());
    _engine.reset();
    state = const FocusSessionState();
    _loadAvailableApps(); // Reload for next session
  }

  void dismissAlert() => state = state.copyWith(showAlert: false);

  void snoozeApp(String packageName) {
    _engine.snooze(packageName, 5); // 5 minutes snooze
    state = state.copyWith(showAlert: false);
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
    state = state.copyWith(
      distractionCount: state.distractionCount + 1,
      currentRiskScore: risk,
      showAlert: true,
      lastDistractionPackage: packageName,
      lastDistractionLabel: event.appLabel,
      lastEventId: event.id,
    );
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

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _browserSubscription?.cancel();
    super.dispose();
  }
}

final focusSessionProvider = StateNotifierProvider<FocusSessionViewModel, FocusSessionState>(
  (ref) => FocusSessionViewModel(
    AppDependencies.prefs,
    AppDependencies.sessionDao,
    AppDependencies.eventDao,
    AppDependencies.syncService,
  ),
);
