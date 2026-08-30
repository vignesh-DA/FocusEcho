/// One row per intervention shown, dismissed, or acted upon during a session.
/// Feeds the Recovery Rate / intervention analytics (Feature 2 -> Feature 3).
class InterventionEvent {
  const InterventionEvent({
    required this.id,
    required this.sessionId,
    required this.level,
    required this.actionTaken,
    required this.timestamp,
    this.isSynced = false,
  });

  /// Escalation ladder:
  /// 1 = heads-up notification, 2-3 = full-screen alert, 4+ = forced choice.
  final String id;
  final String sessionId;
  final int level;
  final String actionTaken;
  final DateTime timestamp;
  final bool isSynced;

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'level': level,
      'action_taken': actionTaken,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  static InterventionEvent fromSqliteMap(Map<String, dynamic> map) {
    return InterventionEvent(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      level: (map['level'] as num?)?.toInt() ?? 1,
      actionTaken: map['action_taken'] as String? ?? 'shown',
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }
}