import 'package:flutter/foundation.dart';
import '../core/models/distraction_event.dart';
import 'database_helper.dart';

class DistractionEventDao {
  DistractionEventDao(this._databaseHelper);

  final DatabaseHelper _databaseHelper;

  Future<void> insertEvent(DistractionEvent event) async {
    if (kIsWeb) {
      DatabaseHelper.webEvents.add(Map<String, dynamic>.from(event.toSqliteMap()));
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.insert('distraction_events', event.toSqliteMap());
  }

  Future<void> updateRecovery(
    String eventId,
    DateTime recoveredAt,
    int recoverySeconds, {
    bool returnedToOrigin = false,
  }) async {
    if (kIsWeb) {
      final index = DatabaseHelper.webEvents.indexWhere((e) => e['id'] == eventId);
      if (index != -1) {
        DatabaseHelper.webEvents[index]['recovered_at'] = recoveredAt.toIso8601String();
        DatabaseHelper.webEvents[index]['recovery_time_seconds'] = recoverySeconds;
        DatabaseHelper.webEvents[index]['is_recovered'] = 1;
        DatabaseHelper.webEvents[index]['returned_to_origin'] = returnedToOrigin ? 1 : 0;
      }
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.update(
      'distraction_events',
      {
        'recovered_at': recoveredAt.toIso8601String(),
        'recovery_time_seconds': recoverySeconds,
        'is_recovered': 1,
        'returned_to_origin': returnedToOrigin ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  Future<List<DistractionEvent>> getUnsyncedEvents() async {
    if (kIsWeb) {
      final unsynced = DatabaseHelper.webEvents.where((e) => e['is_synced'] == 0 || e['is_synced'] == false).toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['triggered_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['triggered_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aTime.compareTo(bTime);
        });
      return unsynced.map(DistractionEvent.fromSqliteMap).toList();
    }
    final db = await _databaseHelper.getDatabase();
    final maps =
        await db.query('distraction_events', where: 'is_synced = 0', orderBy: 'triggered_at ASC');
    return maps.map(DistractionEvent.fromSqliteMap).toList();
  }

  Future<void> markAsSynced(String eventId) async {
    if (kIsWeb) {
      final index = DatabaseHelper.webEvents.indexWhere((e) => e['id'] == eventId);
      if (index != -1) {
        DatabaseHelper.webEvents[index]['is_synced'] = 1;
      }
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.update('distraction_events', {'is_synced': 1}, where: 'id = ?', whereArgs: [eventId]);
  }

  Future<List<DistractionEvent>> getEventsForSession(String sessionId) async {
    if (kIsWeb) {
      final sessionEvents = DatabaseHelper.webEvents.where((e) => e['session_id'] == sessionId).toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['triggered_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['triggered_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aTime.compareTo(bTime);
        });
      return sessionEvents.map(DistractionEvent.fromSqliteMap).toList();
    }
    final db = await _databaseHelper.getDatabase();
    final maps = await db.query(
      'distraction_events',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'triggered_at ASC',
    );
    return maps.map(DistractionEvent.fromSqliteMap).toList();
  }

  Future<List<DistractionEvent>> getRecentEvents(int minutes, {String? eventType}) async {
    if (kIsWeb) {
      final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
      final filtered = DatabaseHelper.webEvents.where((e) {
        final time = DateTime.tryParse(e['triggered_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (time.isBefore(cutoff)) return false;
        if (eventType != null && e['event_type'] != eventType) return false;
        return true;
      }).toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['triggered_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['triggered_at'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aTime.compareTo(bTime);
        });
      return filtered.map(DistractionEvent.fromSqliteMap).toList();
    }
    final db = await _databaseHelper.getDatabase();
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes)).toIso8601String();
    final where = StringBuffer('triggered_at >= ?');
    final args = <Object?>[cutoff];
    if (eventType != null) {
      where.write(' AND event_type = ?');
      args.add(eventType);
    }
    final maps = await db.query(
      'distraction_events',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'triggered_at ASC',
    );
    return maps.map(DistractionEvent.fromSqliteMap).toList();
  }

  Future<void> clearAllEvents() async {
    if (kIsWeb) {
      DatabaseHelper.webEvents.clear();
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.delete('distraction_events');
  }

  /// Marks all unsynced events belonging to a set of session IDs as unsynced
  /// so they get picked up by the next sync after a user logs in.
  Future<void> markEventsUnsyncedForSessions(List<String> sessionIds) async {
    if (sessionIds.isEmpty) return;
    if (kIsWeb) {
      for (final event in DatabaseHelper.webEvents) {
        if (sessionIds.contains(event['session_id'])) {
          event['is_synced'] = 0;
        }
      }
      return;
    }
    final db = await _databaseHelper.getDatabase();
    final placeholders = sessionIds.map((_) => '?').join(',');
    await db.rawUpdate(
      'UPDATE distraction_events SET is_synced = 0 WHERE session_id IN ($placeholders) AND is_synced = 0',
      sessionIds,
    );
  }
}
