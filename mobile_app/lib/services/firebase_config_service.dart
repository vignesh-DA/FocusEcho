import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FirebaseConfigService {
  FirebaseConfigService._();

  static const MethodChannel _channel = MethodChannel('focus_echo/firebase_config');

  static Future<bool> isConfigured() async {
    if (kIsWeb) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isFirebaseConfigured');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
