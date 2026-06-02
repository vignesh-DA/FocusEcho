import 'package:flutter/foundation.dart';
import '../core/models/focus_session.dart';
import 'database_helper.dart';

class FocusSessionDao {
  FocusSessionDao(this._databaseHelper);

  final DatabaseHelper _databaseHelper;

  Future<void> insertSession(FocusSession session) async {
    if (kIsWeb) {
      DatabaseHelper.webSessions.add(Map<String, dynamic>.from(session.toSqliteMap()));
      await DatabaseHelper.persistWeb();
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.insert('focus_sessions', session.toSqliteMap());
  }

  Future<void> updateSessionEnd(
    String sessionId,
    DateTime endTime,
    int totalDistractions,
    int totalXp,
    double focusScore,
    String status,
  ) async {
    if (kIsWeb) {
      final index = DatabaseHelper.webSessions.indexWhere((s) => s['id'] == sessionId);
      if (index != -1) {
        DatabaseHelper.webSessions[index]['end_time'] = endTime.toIso8601String();
        DatabaseHelper.webSessions[index]['total_distractions'] = totalDistractions;
        DatabaseHelper.webSessions[index]['total_xp_earned'] = totalXp;
        DatabaseHelper.webSessions[index]['focus_score'] = focusScore;
        DatabaseHelper.webSessions[index]['status'] = status;
      }
      await DatabaseHelper.persistWeb();
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.update(
      'focus_sessions',
      {
        'end_time': endTime.toIso8601String(),
        'total_distractions': totalDistractions,
        'total_xp_earned': totalXp,
        'focus_score': focusScore,
        'status': status,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<FocusSession?> getActiveSession() async {
    if (kIsWeb) {
      final active = DatabaseHelper.webSessions.firstWhere(
        (s) => s['status'] == 'active',
        orElse: () => <String, dynamic>{},
      );
      if (active.isEmpty) return null;
      return FocusSession.fromSqliteMap(active);
    }
    final db = await _databaseHelper.getDatabase();
    final maps = await db.query('focus_sessions', where: "status = 'active'", limit: 1);
    if (maps.isEmpty) return null;
    return FocusSession.fromSqliteMap(maps.first);
  }

  Future<List<FocusSession>> getSessionHistory(int limit) async {
    if (kIsWeb) {
      final sorted = List<Map<String, dynamic>>.from(DatabaseHelper.webSessions)
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['start_time'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = DateTime.tryParse(b['start_time'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      final limited = sorted.take(limit).toList();
      return limited.map(FocusSession.fromSqliteMap).toList();
    }
    final db = await _databaseHelper.getDatabase();
    final maps = await db.query('focus_sessions', orderBy: 'start_time DESC', limit: limit);
    return maps.map(FocusSession.fromSqliteMap).toList();
  }

  Future<List<FocusSession>> getUnsyncedSessions() async {
    if (kIsWeb) {
      final unsynced = DatabaseHelper.webSessions.where((s) => s['is_synced'] == 0 || s['is_synced'] == false).toList();
      return unsynced.map(FocusSession.fromSqliteMap).toList();
    }
    final db = await _databaseHelper.getDatabase();
    final maps = await db.query('focus_sessions', where: 'is_synced = 0');
    return maps.map(FocusSession.fromSqliteMap).toList();
  }

  Future<void> markAsSynced(String sessionId) async {
    if (kIsWeb) {
      final index = DatabaseHelper.webSessions.indexWhere((s) => s['id'] == sessionId);
      if (index != -1) {
        DatabaseHelper.webSessions[index]['is_synced'] = 1;
      }
      await DatabaseHelper.persistWeb();
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.update('focus_sessions', {'is_synced': 1}, where: 'id = ?', whereArgs: [sessionId]);
  }

  Future<void> clearAllSessions() async {
    if (kIsWeb) {
      DatabaseHelper.webSessions.clear();
      await DatabaseHelper.persistWeb();
      return;
    }
    final db = await _databaseHelper.getDatabase();
    await db.delete('focus_sessions');
  }

  /// Re-assigns all unsynced sessions created as a guest ('local-user')
  /// to the real Supabase UUID after the user signs in.
  Future<int> reassignUserId(String fromUserId, String toUserId) async {
    if (kIsWeb) {
      var count = 0;
      for (final s in DatabaseHelper.webSessions) {
        if (s['user_id'] == fromUserId && (s['is_synced'] == 0 || s['is_synced'] == false)) {
          s['user_id'] = toUserId;
          s['is_synced'] = 0;
          count++;
        }
      }
      await DatabaseHelper.persistWeb();
      return count;
    }
    final db = await _databaseHelper.getDatabase();
    return db.update(
      'focus_sessions',
      {'user_id': toUserId, 'is_synced': 0},
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [fromUserId],
    );
  }
}
