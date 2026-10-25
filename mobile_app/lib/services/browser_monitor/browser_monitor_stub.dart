import 'dart:async';

import 'browser_activity.dart';

class BrowserMonitor {
  BrowserMonitor._();
  static final BrowserMonitor instance = BrowserMonitor._();

  bool get isSupported => false;
  bool get extensionConnected => false;
  Stream<bool> get connectionStatus => const Stream.empty();
  Stream<BrowserActivity> get activities => const Stream.empty();
  Map<String, dynamic>? get activeExtensionSession => null;
  Stream<Map<String, dynamic>?> get activeSessionUpdates => const Stream.empty();

  Future<void> initialize() async {}
  Future<void> startSession(
    List<String> distractingSites, {
    String? sessionId,
    String? intention,
    String? userId,
  }) async {}
  Future<void> stopSession() async {}
  void pushCredentialsToExtension({
    required String authToken,
    required String userId,
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) {}
  void syncCredentialsIfAvailable() {}
}
