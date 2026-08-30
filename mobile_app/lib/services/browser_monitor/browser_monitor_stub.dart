import 'dart:async';

import 'browser_activity.dart';

class BrowserMonitor {
  BrowserMonitor._();
  static final BrowserMonitor instance = BrowserMonitor._();

  bool get isSupported => false;
  Stream<BrowserActivity> get activities => const Stream.empty();
  Future<void> initialize() async {}
  Future<void> startSession(List<String> distractingSites) async {}
  Future<void> stopSession() async {}
}
