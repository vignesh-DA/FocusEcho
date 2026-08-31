// ignore_for_file: lines_longer_than_80_chars
//
// FocusEcho — Focus Session ViewModel Unit Tests
// Covers:
//   TC_SESSION_001 – 004  (timer)
//   TC_INTENT_001 – 003   (focus intent)
//   TC_DISTRACT_001 – 006 (distraction simulation & counter)
//   TC_ESCALATE_001 – 003 (escalation ladder — ViewModel state only)
//   TC_STOP_001 – 002     (stop session)
//
// Running:
//   cd mobile_app
//   flutter test test/focus_session_viewmodel_test.dart --reporter=expanded
//
// Plugin stubs required (set up in setUp):
//   • 'focus_echo/session' MethodChannel — stub returns null (no-op startSession)
//   • AppDependencies.supabaseService — stub Fake (prevents LateInitError in dispose)
//   • SharedPreferences — mock initial values
//
// NOTE (TC_DISTRACT_006):
//   [simulateWebDistraction] is the ONLY entry point for web-demo events.
//   It does NOT call [onDistractionDetected] or [_engine.handleSignal].
//   Zero DAO insertions + counter increment = proof of path isolation.
//
// APPIUM NOTE (TC_ESCALATE_001–003):
//   BLOCKED on Android Appium — kIsWeb simulate button not available.
//   These ViewModel tests are the primary escalation coverage.
// ---------------------------------------------------------------------------

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gotrue/gotrue.dart' show User;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focus_echo_ai/core/constants/app_constants.dart';
import 'package:focus_echo_ai/core/models/distraction_event.dart';
import 'package:focus_echo_ai/core/models/focus_session.dart';
import 'package:focus_echo_ai/core/models/intervention_event.dart';
import 'package:focus_echo_ai/core/providers/app_dependencies.dart';
import 'package:focus_echo_ai/local_db/database_helper.dart';
import 'package:focus_echo_ai/local_db/distraction_event_dao.dart';
import 'package:focus_echo_ai/local_db/focus_session_dao.dart';
import 'package:focus_echo_ai/local_db/intervention_event_dao.dart';
import 'package:focus_echo_ai/services/supabase_service.dart';
import 'package:focus_echo_ai/services/sync_service.dart';
import 'package:focus_echo_ai/features/focus_session/focus_session_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake DAO & service stubs
// ─────────────────────────────────────────────────────────────────────────────

class _FakeDistractionEventDao extends DistractionEventDao {
  _FakeDistractionEventDao() : super(DatabaseHelper.instance);
  final List<DistractionEvent> _events = [];
  List<DistractionEvent> get all => List.unmodifiable(_events);

  @override Future<void> insertEvent(DistractionEvent event) async => _events.add(event);
  @override Future<void> updateRecovery(String eventId, DateTime recoveredAt, int recoverySeconds, {bool returnedToOrigin = false}) async {
    final idx = _events.indexWhere((e) => e.id == eventId);
    if (idx != -1) _events[idx] = _events[idx].copyWith(recoveredAt: recoveredAt, recoveryTimeSeconds: recoverySeconds, isRecovered: true, returnedToOrigin: returnedToOrigin);
  }
  @override Future<List<DistractionEvent>> getEventsForSession(String sessionId) async => _events.where((e) => e.sessionId == sessionId).toList();
  @override Future<List<DistractionEvent>> getRecentEvents(int minutes, {String? eventType}) async {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _events.where((e) { if (e.triggeredAt.isBefore(cutoff)) return false; if (eventType != null && e.eventType != eventType) return false; return true; }).toList();
  }
  @override Future<List<DistractionEvent>> getUnsyncedEvents() async => _events.where((e) => !e.isSynced).toList();
  @override Future<void> markAsSynced(String eventId) async { final idx = _events.indexWhere((e) => e.id == eventId); if (idx != -1) _events[idx] = _events[idx].copyWith(isSynced: true); }
  @override Future<void> markAsUnsynced(String eventId) async { final idx = _events.indexWhere((e) => e.id == eventId); if (idx != -1) _events[idx] = _events[idx].copyWith(isSynced: false); }
  @override Future<void> clearAllEvents() async => _events.clear();
  @override Future<void> markEventsUnsyncedForSessions(List<String> sessionIds) async { for (var i = 0; i < _events.length; i++) { if (sessionIds.contains(_events[i].sessionId)) _events[i] = _events[i].copyWith(isSynced: false); } }
}

class _FakeFocusSessionDao extends FocusSessionDao {
  _FakeFocusSessionDao() : super(DatabaseHelper.instance);
  final List<Map<String, dynamic>> _sessions = [];

  @override Future<void> insertSession(FocusSession session) async => _sessions.add(Map<String, dynamic>.from(session.toSqliteMap()));
  @override Future<void> updateSessionEnd(String sessionId, DateTime endTime, int totalDistractions, int totalXp, double focusScore, String status) async {
    final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
    if (idx == -1) return;
    _sessions[idx]['end_time'] = endTime.toIso8601String();
    _sessions[idx]['total_distractions'] = totalDistractions;
    _sessions[idx]['total_xp_earned'] = totalXp;
    _sessions[idx]['focus_score'] = focusScore;
    _sessions[idx]['status'] = status;
  }
  @override Future<FocusSession?> getActiveSession() async { final active = _sessions.where((s) => s['status'] == 'active'); return active.isEmpty ? null : FocusSession.fromSqliteMap(active.first); }
  @override Future<List<FocusSession>> getSessionHistory(int limit) async => _sessions.take(limit).map(FocusSession.fromSqliteMap).toList();
  @override Future<List<FocusSession>> getUnsyncedSessions() async => [];
  @override Future<void> markAsSynced(String sessionId) async {}
  @override Future<void> clearAllSessions() async => _sessions.clear();
  @override Future<int> reassignUserId(String fromUserId, String toUserId) async => 0;
}

class _FakeInterventionEventDao extends InterventionEventDao {
  _FakeInterventionEventDao() : super(DatabaseHelper.instance);
  final List<InterventionEvent> _events = [];
  List<InterventionEvent> get all => List.unmodifiable(_events);

  @override Future<void> insertEvent(InterventionEvent event) async => _events.add(event);
  @override Future<List<InterventionEvent>> getUnsyncedInterventions() async => [];
  @override Future<void> markAsSynced(String eventId) async {}
  @override Future<List<InterventionEvent>> getEventsForSession(String sessionId) async => _events.where((e) => e.sessionId == sessionId).toList();
  @override Future<void> clearAll() async => _events.clear();
}

/// Stub SyncService via Fake — prevents any network/Supabase call.
class _FakeSyncService extends Fake implements SyncService {
  @override
  Future<SyncResult> syncPendingEvents() async =>
      const SyncResult(synced: 0, failed: 0, skipped: 0, noConnection: true);
}

/// Stub SupabaseService via Fake — prevents LateInitializationError when
/// AppDependencies.supabaseService is accessed during dispose().
class _FakeSupabaseService extends Fake implements SupabaseService {
  @override
  User? get currentUser => null;
  @override
  void unsubscribeFromInterventions() {}
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

typedef _VmBundle = ({
  FocusSessionViewModel vm,
  _FakeDistractionEventDao eventDao,
  _FakeFocusSessionDao sessionDao,
  _FakeInterventionEventDao interventionDao,
});

/// Installs a no-op handler on the 'focus_echo/session' MethodChannel so that
/// `_sessionChannel.invokeMethod('startSession')` / 'stopSession' returns null
/// instead of throwing MissingPluginException.
void _stubSessionChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(AppChannels.session),
    (MethodCall call) async => null,
  );
}

/// Installs a no-op handler on the 'focus_echo/distraction_stream' EventChannel.
void _stubDistractionStreamChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    const EventChannel(AppChannels.distractionStream),
    MockStreamHandler.inline(onListen: (args, sink) {}, onCancel: (_) {}),
  );
}

Future<_VmBundle> _makeVm({
  List<String> productiveApps = const ['com.example.notes'],
}) async {
  // Stub platform channels
  _stubSessionChannel();
  _stubDistractionStreamChannel();

  // Stub AppDependencies so dispose() doesn't hit LateInitializationError
  AppDependencies.supabaseService = _FakeSupabaseService();

  SharedPreferences.setMockInitialValues({
    'productive_apps': '[${productiveApps.map((a) => '"$a"').join(',')}]',
    'userId': 'test-user-001',
    AppKeys.localOnlyMode: true,
    AppKeys.syncEnabled: false,
    AppKeys.crossSurfaceNudges: false,
  });
  final prefs = await SharedPreferences.getInstance();

  final eventDao = _FakeDistractionEventDao();
  final sessionDao = _FakeFocusSessionDao();
  final interventionDao = _FakeInterventionEventDao();
  final syncService = _FakeSyncService();

  final vm = FocusSessionViewModel(
    prefs, sessionDao, eventDao, interventionDao, syncService,
  );

  return (
    vm: vm,
    eventDao: eventDao,
    sessionDao: sessionDao,
    interventionDao: interventionDao,
  );
}

Future<void> _startSession(
  FocusSessionViewModel vm, {
  String app = 'com.example.notes',
  String intent = 'finish my work',
}) async {
  vm.selectProductiveApp(app);
  vm.setIntent(intent);
  await vm.startSession(app, intent: intent);
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── TC_SESSION — Timer ──────────────────────────────────────────────────────
  group('TC_SESSION — Timer', () {
    test('TC_SESSION_001: elapsedSeconds is 0 immediately after startSession',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);

      expect(vm.state.elapsedSeconds, equals(0),
          reason: 'Timer must display 00:00:00 at session start (TC_SESSION_001)');
      expect(vm.state.isActive, isTrue);
    });

    test('TC_SESSION_002: elapsedSeconds increments accurately (±1 s tolerance)',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      final before = vm.state.elapsedSeconds;
      await Future<void>.delayed(const Duration(seconds: 2));
      final after = vm.state.elapsedSeconds;

      expect(after, greaterThanOrEqualTo(before + 1),
          reason: 'Timer must increment at least 1 s (TC_SESSION_002)');
      expect(after, lessThanOrEqualTo(before + 3),
          reason: 'Timer drift within ±1 s tolerance (TC_SESSION_002)');
    });

    // TC_SESSION_003 — background persistence tested by Appium (stateful_driver).

    test('TC_SESSION_004: elapsedSeconds freezes after stopSession', () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      await Future<void>.delayed(const Duration(seconds: 2));
      await vm.stopSession();

      final frozenValue = vm.state.elapsedSeconds;
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(vm.state.elapsedSeconds, equals(frozenValue),
          reason: 'elapsedSeconds must freeze after stopSession (TC_SESSION_004)');
      expect(vm.state.isActive, isFalse);
    });

    test('TC_SESSION_004 (part 2): SessionSummary.actualSeconds recorded',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      await Future<void>.delayed(const Duration(seconds: 2));
      final elapsedAtStop = vm.state.elapsedSeconds;
      await vm.stopSession();

      expect(vm.state.sessionSummary, isNotNull);
      expect(vm.state.sessionSummary!.actualSeconds,
          greaterThanOrEqualTo(elapsedAtStop),
          reason: 'SessionSummary.actualSeconds must reflect duration (TC_SESSION_004)');
    });
  });

  // ── TC_INTENT — Focus Intent ─────────────────────────────────────────────────
  group('TC_INTENT — Focus Intent', () {
    test('TC_INTENT_001: session.intent matches string entered at setup',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      const intentText = 'finish my work';
      await _startSession(vm, intent: intentText);

      expect(vm.state.session?.intent, equals(intentText),
          reason: 'Session intent must exactly match user entry (TC_INTENT_001)');
      expect(vm.state.intent, equals(intentText));
    });

    test('TC_INTENT_002: empty intent does NOT start a session', () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      vm.selectProductiveApp('com.example.notes');
      vm.setIntent('');
      await vm.startSession('com.example.notes', intent: '');

      expect(vm.state.isActive, isFalse,
          reason: 'Session must NOT start with blank intent (TC_INTENT_002)');
      expect(vm.state.session, isNull);
    });

    test('TC_INTENT_002 (whitespace): whitespace-only intent also blocked',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      vm.selectProductiveApp('com.example.notes');
      vm.setIntent('   ');
      await vm.startSession('com.example.notes', intent: '   ');

      expect(vm.state.isActive, isFalse,
          reason: 'Whitespace-only intent treated as empty (TC_INTENT_002)');
    });

    test('TC_INTENT_003: SessionSummary retains intent after stopSession',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      const intentText = 'ship the analytics feature';
      await _startSession(vm, intent: intentText);
      await vm.stopSession();

      expect(vm.state.sessionSummary?.intent, equals(intentText),
          reason: 'Intent must persist into SessionSummary (TC_INTENT_003)');
    });
  });

  // ── TC_DISTRACT — Distraction Simulation & Counter ──────────────────────────
  group('TC_DISTRACT — Distraction Simulation & Counter', () {
    test('TC_DISTRACT_001: simulateWebDistraction creates event in state',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');

      expect(vm.state.lastDistractionPackage, equals('com.instagram.android'),
          reason: 'lastDistractionPackage must reflect simulated event (TC_DISTRACT_001)');
      expect(vm.state.lastDistractionLabel, equals('Instagram'));
      expect(vm.state.lastEventId, isNotNull);
    });

    test('TC_DISTRACT_002: distractionCount goes 0→1 on one simulate tap',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      expect(vm.state.distractionCount, equals(0));

      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');

      // FAILS against the unfixed build (Bug 1) — intentional per TC_DISTRACT_002.
      expect(vm.state.distractionCount, equals(1),
          reason: '"Distractions: N" must read 1 after one simulate tap '
              '(TC_DISTRACT_002 — fails if Bug 1 unfixed)');
    });

    test('TC_DISTRACT_003: counter reads exactly 4 after 4 simulate taps',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      for (var i = 0; i < 4; i++) {
        await vm.simulateWebDistraction('com.instagram.android', 'Instagram');
      }

      expect(vm.state.distractionCount, equals(4),
          reason: 'No double-count or drop — exactly 4 (TC_DISTRACT_003)');
    });

    test('TC_DISTRACT_004: distractionCount resets to 0 on a new session',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm, intent: 'first session');
      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');
      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');
      expect(vm.state.distractionCount, equals(2));

      await vm.stopSession();
      vm.dismissSummary();

      await _startSession(vm, intent: 'second session');

      expect(vm.state.distractionCount, equals(0),
          reason: 'New session must start with distractionCount=0 (TC_DISTRACT_004)');
    });

    test('TC_DISTRACT_005: simulated events NOT inserted into DistractionEventDao',
        () async {
      // Web-demo events excluded from real analytics storage.
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');

      expect(eventDao.all.isEmpty, isTrue,
          reason: 'Simulated events must NOT be inserted into DAO (TC_DISTRACT_005)');
    });

    test(
        'TC_DISTRACT_006: simulateWebDistraction isolated from FocusDetectionEngine '
        '— no DAO writes, counter still increments', () async {
      // IMPORTANT: This test is NOT equivalent to real distraction detection
      // testing.  [simulateWebDistraction] calls [_registerDistraction] directly
      // and does NOT call onDistractionDetected, _engine.handleSignal, or
      // the native EventChannel.
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      final daoCountBefore = eventDao.all.length;

      await vm.simulateWebDistraction('com.google.android.youtube', 'YouTube');

      expect(eventDao.all.length, equals(daoCountBefore),
          reason: '[TC_DISTRACT_006] simulateWebDistraction must NOT write to '
              'DistractionEventDao — failure means path re-routed through real '
              'detection. THIS IS NOT REAL DETECTION COVERAGE.');
      expect(vm.state.distractionCount, equals(1));
    });
  });

  // ── TC_ESCALATE — Escalation Ladder ─────────────────────────────────────────
  // APPIUM EQUIVALENTS: BLOCKED — kIsWeb simulate button hidden on Android Appium.
  // These ViewModel tests are the primary escalation coverage.
  group('TC_ESCALATE — Escalation Ladder (ViewModel state)', () {
    test('TC_ESCALATE_001: escalationLevel = 1 after first distraction',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');

      expect(vm.state.escalationLevel, equals(1),
          reason: 'First relapse → Level 1 heads-up modal (TC_ESCALATE_001)');
      expect(vm.state.showAlert, isTrue);
    });

    test('TC_ESCALATE_002: escalationLevel = 2 after 2nd–3rd distraction',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);

      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');
      expect(vm.state.escalationLevel, equals(1));
      vm.returnToFocusFromIntervention();

      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');
      expect(vm.state.escalationLevel, equals(2),
          reason: 'Second relapse → Level 2 full-screen overlay (TC_ESCALATE_002)');

      vm.returnToFocusFromIntervention();
      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');
      expect(vm.state.escalationLevel, equals(2),
          reason: 'Third relapse → still Level 2 (TC_ESCALATE_002)');
    });

    test('TC_ESCALATE_003: escalationLevel = 3 after 4th+ distraction',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm);
      for (var i = 0; i < 3; i++) {
        await vm.simulateWebDistraction('com.instagram.android', 'Instagram');
        vm.returnToFocusFromIntervention();
      }
      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');

      expect(vm.state.escalationLevel, equals(3),
          reason: '4th+ relapse → Level 3 forced-choice overlay (TC_ESCALATE_003)');
      expect(vm.state.showAlert, isTrue);
    });
  });

  // ── TC_STOP — Stop Session ───────────────────────────────────────────────────
  group('TC_STOP — Stop Session', () {
    test('TC_STOP_001: stopSession records correct intent, duration, distraction count',
        () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      const intent = 'finish the report';
      await _startSession(vm, intent: intent);
      await Future<void>.delayed(const Duration(seconds: 2));

      final elapsedAtStop = vm.state.elapsedSeconds;
      await vm.stopSession();

      final summary = vm.state.sessionSummary;
      expect(summary, isNotNull,
          reason: 'SessionSummary must exist after stopSession (TC_STOP_001)');
      expect(summary!.intent, equals(intent),
          reason: 'Stored intent must match session intent (TC_STOP_001)');
      expect(summary.actualSeconds, greaterThanOrEqualTo(elapsedAtStop),
          reason: 'Stored duration must match elapsed time (TC_STOP_001)');
      expect(summary.totalDistractions, equals(0),
          reason: 'Web-demo events excluded from session record (TC_STOP_001)');
      expect(vm.state.isActive, isFalse);
    });

    test('TC_STOP_002: stopSession mid-distraction completes cleanly', () async {
      final (:vm, :eventDao, :sessionDao, :interventionDao) = await _makeVm();
      addTearDown(vm.dispose);

      await _startSession(vm, intent: 'quick stop test');
      await vm.simulateWebDistraction('com.instagram.android', 'Instagram');

      await expectLater(vm.stopSession(), completes,
          reason: 'stopSession must not throw mid-distraction (TC_STOP_002)');

      expect(vm.state.isActive, isFalse,
          reason: 'Session must be inactive after stop (TC_STOP_002)');
      expect(vm.state.sessionSummary, isNotNull,
          reason: 'Summary must be available (TC_STOP_002)');
      expect(vm.state.showAlert, isFalse,
          reason: 'Alert must be cleared when session stops (TC_STOP_002)');
    });
  });
}
