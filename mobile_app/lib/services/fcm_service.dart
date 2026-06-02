import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

class FcmService {
  FcmService(this._prefs);

  final SharedPreferences _prefs;
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'focus_echo_streaks',
    'Focus Echo Alerts',
    description: 'Alerts for focus and streak risk events',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (kIsWeb) return;

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    _messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging!.requestPermission(alert: true, badge: true, sound: true, provisional: false);
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _saveToken(await _messaging!.getToken());
    _messaging!.onTokenRefresh.listen(_saveToken);

    FirebaseMessaging.onMessage.listen((message) async {
      if (!_isStreakRiskMessage(message)) return;
      final notification = message.notification;
      await _localNotifications.show(
        message.hashCode,
        notification?.title ?? 'Streak at Risk',
        notification?.body ?? 'Open Focus Echo to keep your streak alive.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'focus_echo_streaks',
            'Focus Echo Alerts',
            channelDescription: 'Alerts for focus and streak risk events',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  Future<void> _saveToken(String? token) async {
    if (token == null || token.isEmpty) return;
    await _prefs.setString('fcm_token', token);
  }

  bool _isStreakRiskMessage(RemoteMessage message) {
    final type = message.data['type'];
    if (type == 'streak_risk') return true;
    final title = message.notification?.title?.toLowerCase() ?? '';
    return title.contains('streak') || title.contains('focus');
  }
}
