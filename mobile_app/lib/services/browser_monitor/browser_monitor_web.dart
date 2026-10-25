import 'dart:async';
import 'dart:html';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import 'browser_activity.dart';

class BrowserMonitor {
  BrowserMonitor._();
  static final BrowserMonitor instance = BrowserMonitor._();

  final _activities = StreamController<BrowserActivity>.broadcast();
  final _connectionStatus = StreamController<bool>.broadcast();
  final _activeSessionUpdates =
      StreamController<Map<String, dynamic>?>.broadcast();
  StreamSubscription<MessageEvent>? _messageSubscription;
  StreamSubscription<Event>? _visibilitySubscription;
  Timer? _presenceTimer;
  bool _initialized = false;
  bool _extensionConnected = false;
  Map<String, dynamic>? _activeExtensionSession;

  bool get isSupported => true;
  Stream<BrowserActivity> get activities => _activities.stream;
  bool get extensionConnected => _extensionConnected;
  Stream<bool> get connectionStatus => _connectionStatus.stream;
  Map<String, dynamic>? get activeExtensionSession => _activeExtensionSession;
  Stream<Map<String, dynamic>?> get activeSessionUpdates =>
      _activeSessionUpdates.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _messageSubscription = window.onMessage.listen((message) {
      final data = message.data;
      if (data is! Map) return;
      final source = data['source']?.toString() ?? '';
      final type = data['type']?.toString() ?? '';

      // Extension presence / registration handshake
      if (source == 'focusecho-extension' &&
          (type == 'registered' || type == 'connection')) {
        _extensionConnected = data['connected'] != false;
        _presenceTimer?.cancel();
        _connectionStatus.add(_extensionConnected);

        if (data['activeSession'] != null && data['activeSession'] is Map) {
          _activeExtensionSession =
              Map<String, dynamic>.from(data['activeSession'] as Map);
          _activeSessionUpdates.add(_activeExtensionSession);
        }

        // Push credentials automatically upon connection
        syncCredentialsIfAvailable();
        return;
      }

      if (source == 'focusecho-extension') {
        if (type == 'fe:session_started') {
          if (data['session'] is Map) {
            _activeExtensionSession =
                Map<String, dynamic>.from(data['session'] as Map);
            _activeSessionUpdates.add(_activeExtensionSession);
          }
          return;
        }
        if (type == 'fe:session_stopped') {
          _activeExtensionSession = null;
          _activeSessionUpdates.add(null);
          return;
        }

        // Extension activity events — two message formats handled:
        //   1. Legacy:  { source: 'focusecho-extension', type: 'activity', event: {...} }
        //   2. Current: { source: 'focusecho-extension', type: 'fe:dashboard_activity', kind, host, ... }
        if (type == 'activity') {
          final event = data['event'];
          if (event is Map) {
            // Map 'away' -> 'distraction' so viewmodel triggers alert
            final rawKind = event['kind']?.toString() ?? 'away';
            final kind = (rawKind == 'away') ? 'distraction' : rawKind;
            _emit(
              kind,
              event['host']?.toString() ?? 'unknown',
              event['timestamp']?.toString(),
              (event['escalation_level'] as num?)?.toInt() ?? 1,
            );
          }
          return;
        }
        if (type == 'fe:dashboard_activity') {
          final rawKind = data['kind']?.toString() ?? 'away';
          final kind = (rawKind == 'away') ? 'distraction' : rawKind;
          _emit(
            kind,
            data['host']?.toString() ?? 'unknown',
            data['timestamp']?.toString(),
            (data['escalation_level'] as num?)?.toInt() ?? 1,
          );
          return;
        }
      }
    });
    _visibilitySubscription = document.onVisibilityChange.listen((_) {
      if (document.visibilityState == 'visible') {
        _emit('return', 'focusecho', DateTime.now().toIso8601String(), 1);
      }
    });
    window.postMessage({'source': 'focusecho-web', 'type': 'register'}, '*');
    _presenceTimer?.cancel();
    _presenceTimer = Timer(const Duration(seconds: 3), () {
      _extensionConnected = false;
      _connectionStatus.add(false);
    });
  }

  /// Push Supabase JWT to the extension so it can write to the database.
  void pushCredentialsToExtension({
    required String authToken,
    required String userId,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {
    window.postMessage({
      'source': 'focusecho-web',
      'type': 'fe:save_credentials',
      'authToken': authToken,
      'userId': userId,
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
    }, '*');
  }

  void syncCredentialsIfAvailable() {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;
      if (session != null && user != null) {
        pushCredentialsToExtension(
          authToken: session.accessToken,
          userId: user.id,
          supabaseUrl: AppConfig.supabaseUrl,
          supabaseAnonKey: AppConfig.supabaseAnonKey,
        );
        debugPrint(
            '[BrowserMonitor] Synced auth credentials to extension for user ${user.id}');
      }
    } catch (e) {
      debugPrint('[BrowserMonitor] Could not sync credentials: $e');
    }
  }

  Future<void> startSession(
    List<String> distractingSites, {
    String? sessionId,
    String? intention,
    String? userId,
  }) async {
    await initialize();
    syncCredentialsIfAvailable();
    window.postMessage({
      'source': 'focusecho-web',
      'type': 'configure',
      'active': true,
      'sessionId': sessionId,
      'intention': intention,
      'userId': userId,
      'distractingSites': distractingSites,
    }, '*');
  }

  Future<void> stopSession() async {
    window.postMessage({
      'source': 'focusecho-web',
      'type': 'configure',
      'active': false,
      'distractingSites': const <String>[],
    }, '*');
  }

  void _emit(
      String kind, String host, String? rawTimestamp, int escalationLevel) {
    _activities.add(BrowserActivity(
      kind: kind,
      host: host,
      timestamp: DateTime.tryParse(rawTimestamp ?? '') ?? DateTime.now(),
      escalationLevel: escalationLevel,
    ));
  }

  Future<void> dispose() async {
    _presenceTimer?.cancel();
    await _messageSubscription?.cancel();
    await _visibilitySubscription?.cancel();
    await _activities.close();
    await _connectionStatus.close();
    await _activeSessionUpdates.close();
  }
}
