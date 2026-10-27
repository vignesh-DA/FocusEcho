import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;

class WebNotificationService {
  WebNotificationService._();
  static final WebNotificationService instance = WebNotificationService._();

  static const _tag = 'focusecho-distraction';
  static const _repeatInterval = Duration(seconds: 30);

  Timer? _repeatTimer;
  String? _activeLabel;
  int _activeLevel = 1;
  Object? _activeNotification;
  DateTime? _startedAt;

  /// Must be called directly from the session-start user gesture.
  Future<void> requestPermissionFromUserGesture() async {
    try {
      if (html.Notification.permission == 'default') {
        await html.Notification.requestPermission();
      }
    } catch (_) {
      // Some browsers block prompts outside a trusted user gesture.
    }
  }

  Future<void> showDistractionAlert(String appLabel, int level) async {
    if (html.Notification.permission != 'granted') return;
    _activeLabel = appLabel.trim().isEmpty ? 'this site' : appLabel.trim();
    _activeLevel = level.clamp(1, 3).toInt();
    _startedAt ??= DateTime.now();
    await _showNow();
    _repeatTimer ??= Timer.periodic(_repeatInterval, (_) {
      unawaited(_showNow());
    });
  }

  Future<void> _showNow() async {
    final label = _activeLabel;
    if (label == null || html.Notification.permission != 'granted') return;
    _closeActive();
    final elapsedMinutes = DateTime.now().difference(_startedAt!).inMinutes;
    final options = <String, Object>{
      'body':
          'You opened $label during your focus session. Return to focus when ready.',
      'icon': 'icons/Icon-192.png',
      'tag': _tag,
      'renotify': true,
      'requireInteraction': true,
      'data': {'level': _activeLevel},
    };
    final constructor = js_util.getProperty(html.window, 'Notification');
    final notification = js_util.callConstructor(
      constructor,
      ['⚠️ Focus check — $label (${elapsedMinutes}m drift)', options],
    );
    js_util.setProperty(notification, 'onclick', js.allowInterop((_) {
      html.window.focus();
    }));
    _activeNotification = notification as Object;
  }

  void _closeActive() {
    final notification = _activeNotification;
    if (notification == null) return;
    try {
      js_util.callMethod<void>(notification, 'close', const []);
    } catch (_) {
      // The browser may already have dismissed the notification.
    }
    _activeNotification = null;
  }

  void clear() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _activeLabel = null;
    _startedAt = null;
    _closeActive();
  }
}
