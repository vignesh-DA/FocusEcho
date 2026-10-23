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
      if (data is! Map || data['source'] != 'focusecho-extension') return;
      if (data['type'] == 'registered' || data['type'] == 'connection') {
        _extensionConnected = data['connected'] != false;
        _presenceTimer?.cancel();
        _connectionStatus.add(_extensionConnected);
        return;
      }
      if (data['type'] != 'activity') return;
      final event = data['event'];
      if (event is! Map) return;
      _emit(
        event['kind']?.toString() ?? 'away',
        event['host']?.toString() ?? 'unknown',
        event['timestamp']?.toString(),
        (event['escalation_level'] as num?)?.toInt() ?? 1,
      );
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
