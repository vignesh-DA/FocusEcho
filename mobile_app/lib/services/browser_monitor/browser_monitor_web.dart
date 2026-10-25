import 'dart:async';
import 'dart:html';

import 'browser_activity.dart';

class BrowserMonitor {
  BrowserMonitor._();
  static final BrowserMonitor instance = BrowserMonitor._();

  final _activities = StreamController<BrowserActivity>.broadcast();
  final _connectionStatus = StreamController<bool>.broadcast();
  StreamSubscription<MessageEvent>? _messageSubscription;
  StreamSubscription<Event>? _visibilitySubscription;
  Timer? _presenceTimer;
  bool _initialized = false;
  bool _extensionConnected = false;

  bool get isSupported => true;
  Stream<BrowserActivity> get activities => _activities.stream;
  bool get extensionConnected => _extensionConnected;
  Stream<bool> get connectionStatus => _connectionStatus.stream;

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
        return;
      }

      // Extension activity events — two message formats handled:
      //   1. Legacy:  { source: 'focusecho-extension', type: 'activity', event: {...} }
      //   2. Current: { source: 'focusecho-extension', type: 'fe:dashboard_activity', kind, host, ... }
      if (source == 'focusecho-extension') {
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

  Future<void> startSession(List<String> distractingSites) async {
    await initialize();
    window.postMessage({
      'source': 'focusecho-web',
      'type': 'configure',
      'active': true,
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
  }
}
