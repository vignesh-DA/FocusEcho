import 'dart:async';

import 'browser_activity.dart';

class BrowserMonitor {
  BrowserMonitor._();
  static final BrowserMonitor instance = BrowserMonitor._();

  bool get isSupported => false;
  bool get extensionConnected => false;
  Stream<bool> get connectionStatus => const Stream.empty();
  Stream<BrowserActivity> get activities => const Stream.empty();
  Future<void> initialize() async {}
  Future<void> startSession(List<String> distractingSites) async {}
  Future<void> stopSession() async {}
}
