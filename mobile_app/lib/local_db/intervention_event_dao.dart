import 'package:flutter/foundation.dart';

import '../core/models/intervention_event.dart';
import 'database_helper.dart';

class InterventionEventDao {
  InterventionEventDao(this._databaseHelper);

  final DatabaseHelper _databaseHelper;

  Future<void> insertEvent(InterventionEvent event) async {
    if (kIsWeb) {
      DatabaseHelper.webInterventions.add(Map<String, dynamic>.from(event.toSqliteMap()));
      await DatabaseHelper.persistWeb();
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.insert('intervention_events', event.toSqliteMap());
  }

  Future<List<InterventionEvent>> getUnsyncedInterventions() async {
    if (kIsWeb) {
      return DatabaseHelper.webInterventions
          .where((e) => e['is_synced'] == 0 || e['is_synced'] == false)
          .map(InterventionEvent.fromSqliteMap)
          .toList();
    }
    final db = await _databaseHelper.getDatabase();
    final maps = await db.query('intervention_events', where: 'is_synced = 0');
    return maps.map(InterventionEvent.fromSqliteMap).toList();
  }

  Future<void> markAsSynced(String eventId) async {
    if (kIsWeb) {
      final index = DatabaseHelper.webInterventions.indexWhere((e) => e['id'] == eventId);
      if (index != -1) {
        DatabaseHelper.webInterventions[index]['is_synced'] = 1;
      }
      await DatabaseHelper.persistWeb();
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.update('intervention_events', {'is_synced': 1}, where: 'id = ?', whereArgs: [eventId]);
  }

  Future<List<InterventionEvent>> getEventsForSession(String sessionId) async {
    if (kIsWeb) {
      return DatabaseHelper.webInterventions
          .where((e) => e['session_id'] == sessionId)
          .map(InterventionEvent.fromSqliteMap)
          .toList();
    }
    final db = await _databaseHelper.getDatabase();
    final maps = await db.query(
      'intervention_events',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return maps.map(InterventionEvent.fromSqliteMap).toList();
  }

  Future<void> clearAll() async {
    if (kIsWeb) {
      DatabaseHelper.webInterventions.clear();
      await DatabaseHelper.persistWeb();
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.delete('intervention_events');
  }
}