import 'dart:async';
import 'dart:html';

import 'browser_activity.dart';

class BrowserMonitor {
  BrowserMonitor._();
  static final BrowserMonitor instance = BrowserMonitor._();

  final _activities = StreamController<BrowserActivity>.broadcast();
  StreamSubscription<MessageEvent>? _messageSubscription;
  StreamSubscription<Event>? _visibilitySubscription;
  bool _initialized = false;

  bool get isSupported => true;
  Stream<BrowserActivity> get activities => _activities.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _messageSubscription = window.onMessage.listen((message) {
      final data = message.data;
      if (data is! Map || data['source'] != 'focusecho-extension' || data['type'] != 'activity') return;
      final event = data['event'];
      if (event is! Map) return;
      _emit(
        event['kind']?.toString() ?? 'away',
        event['host']?.toString() ?? 'unknown',
        event['timestamp']?.toString(),
      );
    });
    _visibilitySubscription = document.onVisibilityChange.listen((_) {
      if (document.visibilityState == 'visible') {
        _emit('return', 'focusecho', DateTime.now().toIso8601String());
      }
    });
    window.postMessage({'source': 'focusecho-web', 'type': 'register'}, '*');
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

  void _emit(String kind, String host, String? rawTimestamp) {
    _activities.add(BrowserActivity(
      kind: kind,
      host: host,
      timestamp: DateTime.tryParse(rawTimestamp ?? '') ?? DateTime.now(),
    ));
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _visibilitySubscription?.cancel();
    await _activities.close();
  }
}
