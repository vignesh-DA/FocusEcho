class BrowserActivity {
  const BrowserActivity({
    required this.kind,
    required this.host,
    required this.timestamp,
    this.escalationLevel = 1,
    this.sessionId,
    this.eventId,
    this.timeAwaySeconds,
  });

  final String kind;
  final String host;
  final DateTime timestamp;

  /// Feature 2 — relapse ladder within the current web session:
  /// 1 = heads-up, 2 = full-screen alert, 3 = forced choice.
  final int escalationLevel;
  final String? sessionId;
  final String? eventId;
  final int? timeAwaySeconds;
}
