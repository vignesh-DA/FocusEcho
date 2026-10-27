import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

class WebNotificationService {
  WebNotificationService._();
  static final WebNotificationService instance = WebNotificationService._();

  static const _tag = 'focusecho-distraction';
  static const _repeatInterval = Duration(seconds: 30);

  Timer? _repeatTimer;
  String? _activeLabel;
  int _activeLevel = 1;
  web.Notification? _activeNotification;
  DateTime? _startedAt;

  /// Must be called directly from the session-start user gesture.
  Future<void> requestPermissionFromUserGesture() async {
    try {
      if (web.Notification.permission == 'default') {
        await web.Notification.requestPermission().toDart;
      }
    } catch (_) {
      // Some browsers block prompts outside a trusted user gesture.
    }
  }

  Future<void> showDistractionAlert(String appLabel, int level) async {
    if (web.Notification.permission != 'granted') return;
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
    if (label == null || web.Notification.permission != 'granted') return;
    _closeActive();
    final elapsedMinutes = DateTime.now().difference(_startedAt!).inMinutes;
    final notification = web.Notification(
      '⚠️ Focus check — $label (${elapsedMinutes}m drift)',
      web.NotificationOptions(
        body:
            'You opened $label during your focus session. Return to focus when ready.',
        icon: 'icons/Icon-192.png',
        tag: _tag,
        renotify: true,
        requireInteraction: true,
        data: {'level': _activeLevel}.jsify(),
      ),
    );
    notification.onclick = ((web.Event _) => web.window.focus()).toJS;
    _activeNotification = notification;
  }

  void _closeActive() {
    final notification = _activeNotification;
    if (notification == null) return;
    try {
      notification.close();
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
