import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../../core/constants/app_constants.dart';
import 'browser_activity.dart';

class BrowserMonitor {
  BrowserMonitor._();
  static final BrowserMonitor instance = BrowserMonitor._();

  final _activities = StreamController<BrowserActivity>.broadcast();
  final _connectionStatus = StreamController<bool>.broadcast();
  final _activeSessionUpdates =
      StreamController<Map<String, dynamic>?>.broadcast();
  late final web.EventListener _messageListener =
      ((web.Event event) => _handleMessage(event as web.MessageEvent)).toJS;
  Timer? _presenceTimer;
  bool _initialized = false;
  bool _extensionConnected = false;
  Map<String, dynamic>? _activeExtensionSession;

  Map<String, dynamic>? _extractMap(Object? raw) {
    if (raw == null) return null;
    try {
      final converted = raw is Map ? raw : (raw as JSAny).dartify();
      if (converted is Map) {
        return converted.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      // Ignore malformed/unserializable messages from unrelated page scripts.
    }
    return null;
  }

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
    web.window.addEventListener('message', _messageListener);
    _postMessage({'source': 'focusecho-web', 'type': 'register'});
    _presenceTimer?.cancel();
    _presenceTimer = Timer(const Duration(seconds: 3), () {
      _extensionConnected = false;
      _connectionStatus.add(false);
    });
  }

  void _handleMessage(web.MessageEvent message) {
    if (message.origin != web.window.location.origin ||
        !(message.source?.strictEquals(web.window).toDart ?? false)) {
      return;
    }
    final data = _extractMap(message.data);
    if (data == null) return;
    final source = data['source']?.toString() ?? '';
    final type = data['type']?.toString() ?? '';

    if (source != 'focusecho-extension') return;

    if (type == 'registered' || type == 'connection') {
      _extensionConnected = data['connected'] != false;
      _presenceTimer?.cancel();
      _connectionStatus.add(_extensionConnected);
      final activeSession = _extractMap(data['activeSession']);
      if (activeSession != null) {
        _activeExtensionSession = activeSession;
        _activeSessionUpdates.add(_activeExtensionSession);
      }
      syncCredentialsIfAvailable();
      return;
    }

    if (type == 'fe:session_started') {
      final session = _extractMap(data['session']);
      if (session != null) {
        _activeExtensionSession = session;
        _activeSessionUpdates.add(_activeExtensionSession);
      }
      return;
    }

    if (type == 'fe:session_stopped') {
      final stoppedSession = _extractMap(data['session']);
      final stoppedId = stoppedSession?['session_id']?.toString();
      final activeId = _activeExtensionSession?['session_id']?.toString();
      if (stoppedId == null || activeId == null || stoppedId == activeId) {
        _activeExtensionSession = null;
        _activeSessionUpdates.add(null);
      }
      return;
    }

    if (type == 'activity') {
      final event = _extractMap(data['event']);
      if (event != null) {
        final rawKind = event['kind']?.toString() ?? 'away';
        _emit(
          rawKind == 'away' ? 'distraction' : rawKind,
          event['host']?.toString() ?? 'unknown',
          event['timestamp']?.toString(),
          (event['escalation_level'] as num?)?.toInt() ?? 1,
          sessionId: event['session_id']?.toString(),
          eventId: event['event_id']?.toString(),
          timeAwaySeconds: (event['time_away_seconds'] as num?)?.toInt(),
        );
      }
      return;
    }

    if (type == 'fe:dashboard_activity') {
      final rawKind = data['kind']?.toString() ?? 'away';
      _emit(
        rawKind == 'away' ? 'distraction' : rawKind,
        data['host']?.toString() ?? 'unknown',
        data['timestamp']?.toString(),
        (data['escalation_level'] as num?)?.toInt() ?? 1,
        sessionId: data['session_id']?.toString(),
        eventId: data['event_id']?.toString(),
        timeAwaySeconds: (data['time_away_seconds'] as num?)?.toInt(),
      );
    }
  }

  void _postMessage(Map<String, Object?> message, {String targetOrigin = '*'}) {
    web.window.postMessage(message.jsify(), targetOrigin.toJS);
  }

  /// Push Supabase JWT to the extension so it can write to the database.
  void pushCredentialsToExtension({
    required String authToken,
    String? refreshToken,
    required String userId,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {
    _postMessage({
      'source': 'focusecho-web',
      'type': 'fe:save_credentials',
      'authToken': authToken,
      'refreshToken': refreshToken,
      'userId': userId,
      'supabaseUrl': supabaseUrl,
      'supabaseAnonKey': supabaseAnonKey,
    });
  }

  void syncCredentialsIfAvailable() {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;
      if (session != null && user != null) {
        pushCredentialsToExtension(
          authToken: session.accessToken,
          refreshToken: session.refreshToken,
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
    _postMessage({
      'source': 'focusecho-web',
      'type': 'configure',
      'active': true,
      'sessionId': sessionId,
      'intention': intention,
      'userId': userId,
      'distractingSites': distractingSites,
    });
  }

  Future<void> stopSession() async {
    _postMessage({
      'source': 'focusecho-web',
      'type': 'configure',
      'active': false,
      'distractingSites': const <String>[],
    });
  }

  void updateParkedItems(List<String> items) {
    _postMessage({
      'source': 'focusecho-web',
      'type': 'fe:parking_items',
      'items': items,
    }, targetOrigin: web.window.location.origin);
  }

  void _emit(
    String kind,
    String host,
    String? rawTimestamp,
    int escalationLevel, {
    String? sessionId,
    String? eventId,
    int? timeAwaySeconds,
  }) {
    _activities.add(BrowserActivity(
      kind: kind,
      host: host,
      timestamp: DateTime.tryParse(rawTimestamp ?? '') ?? DateTime.now(),
      escalationLevel: escalationLevel,
      sessionId: sessionId,
      eventId: eventId,
      timeAwaySeconds: timeAwaySeconds,
    ));
  }

  Future<void> dispose() async {
    _presenceTimer?.cancel();
    web.window.removeEventListener('message', _messageListener);
    await _activities.close();
    await _connectionStatus.close();
    await _activeSessionUpdates.close();
  }
}
