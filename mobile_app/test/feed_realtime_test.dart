import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focus_echo_ai/core/constants/app_constants.dart';
import 'package:focus_echo_ai/core/models/focus_session.dart';
import 'package:focus_echo_ai/core/providers/app_dependencies.dart';
import 'package:focus_echo_ai/features/focus_session/focus_session_screen.dart';
import 'package:focus_echo_ai/features/focus_session/focus_session_state.dart';
import 'package:focus_echo_ai/features/focus_session/focus_session_viewmodel.dart';
import 'package:focus_echo_ai/features/focus_session/widgets/live_distraction_feed.dart';
import 'package:focus_echo_ai/local_db/database_helper.dart';
import 'package:focus_echo_ai/local_db/distraction_event_dao.dart';
import 'package:focus_echo_ai/local_db/focus_session_dao.dart';
import 'package:focus_echo_ai/local_db/intervention_event_dao.dart';
import 'package:focus_echo_ai/services/supabase_service.dart';
import 'package:focus_echo_ai/services/sync_service.dart';

class _FeedSupabaseService extends Fake implements SupabaseService {
  _FeedSupabaseService(this._events);

  final Stream<List<Map<String, dynamic>>> _events;

  @override
  Stream<List<Map<String, dynamic>>> watchDistractionEvents(String sessionId) =>
      _events;

  @override
  void unsubscribeFromInterventions() {}
}

class _SessionDao extends FocusSessionDao {
  _SessionDao() : super(DatabaseHelper.instance);

  @override
  Future<void> insertSession(FocusSession session) async {}
}

class _EventDao extends DistractionEventDao {
  _EventDao() : super(DatabaseHelper.instance);
}

class _InterventionDao extends InterventionEventDao {
  _InterventionDao() : super(DatabaseHelper.instance);
}

class _Sync extends Fake implements SyncService {
  @override
  Future<SyncResult> syncNow() async => SyncResult.noConnection();

  @override
  Future<SyncResult> syncPendingEvents() async => SyncResult.noConnection();
}

Future<FocusSessionViewModel> _makeViewModel(
  SupabaseService supabaseService,
) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(AppChannels.session),
    (MethodCall call) async => null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockStreamHandler(
    const EventChannel(AppChannels.distractionStream),
    MockStreamHandler.inline(onListen: (_, __) {}, onCancel: (_) {}),
  );

  SharedPreferences.setMockInitialValues({
    AppKeys.productiveApps: '["com.example.notes"]',
    AppKeys.userId: 'feed-test-user',
    AppKeys.localOnlyMode: true,
    AppKeys.syncEnabled: false,
  });
  final prefs = await SharedPreferences.getInstance();
  AppDependencies.supabaseService = supabaseService;

  return FocusSessionViewModel(
    prefs,
    _SessionDao(),
    _EventDao(),
    _InterventionDao(),
    _Sync(),
    supabaseService: supabaseService,
  );
}

FocusSessionState _activeState(List<Map<String, dynamic>> feed) {
  final session = FocusSession(
    id: 'feed-session',
    userId: 'feed-test-user',
    startTime: DateTime.now(),
    productiveApp: 'com.example.notes',
    intent: 'finish the dashboard',
  );
  return FocusSessionState(
    isActive: true,
    session: session,
    intent: session.intent,
    availableProductiveApps: const ['com.example.notes'],
    selectedProductiveApp: 'com.example.notes',
    liveDistractionFeed: feed,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Realtime stream updates liveDistractionFeed when a row arrives',
      () async {
    final controller = StreamController<List<Map<String, dynamic>>>();
    final vm = await _makeViewModel(_FeedSupabaseService(controller.stream));
    addTearDown(() async {
      vm.dispose();
      await controller.close();
    });

    await vm.startSession('com.example.notes', intent: 'finish the dashboard');
    controller.add([
      {
        'id': 'event-1',
        'package_name': 'youtube.com',
        'app_label': 'youtube.com',
        'triggered_at': DateTime.now().toIso8601String(),
        'escalation_level': 2,
        'is_recovered': false,
      },
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(vm.state.liveDistractionFeed, hasLength(1));
    expect(vm.state.liveDistractionFeed.single['package_name'], 'youtube.com');
  });

  testWidgets('feed list renders three streamed rows after one pump',
      (tester) async {
    final rows = [
      {
        'id': '1',
        'package_name': 'youtube.com',
        'triggered_at': DateTime.now().toIso8601String(),
        'escalation_level': 1
      },
      {
        'id': '2',
        'package_name': 'reddit.com',
        'triggered_at': DateTime.now().toIso8601String(),
        'escalation_level': 2
      },
      {
        'id': '3',
        'package_name': 'news.ycombinator.com',
        'triggered_at': DateTime.now().toIso8601String(),
        'escalation_level': 1
      },
    ];
    final vm = await _makeViewModel(_FeedSupabaseService(const Stream.empty()));
    vm.state = _activeState(rows);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [focusSessionProvider.overrideWith((ref) => vm)],
        child: const MaterialApp(home: FocusSessionScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(LiveDistractionFeed), findsOneWidget);
    expect(find.text('youtube.com'), findsOneWidget);
    expect(find.text('reddit.com'), findsOneWidget);
    expect(find.text('news.ycombinator.com'), findsOneWidget);
  });

  test('median recovery computation returns the middle recovery value', () {
    final median = medianRecoverySeconds([
      {'recovery_time_seconds': 30},
      {'recovery_time_seconds': 60},
      {'recovery_time_seconds': 90},
    ]);

    expect(median, 60);
  });
}
