import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'focus_echo.db';
  static const _dbVersion = 2;

  Database? _database;

  // In-memory store for Web demo
  static final List<Map<String, dynamic>> webSessions = [];
  static final List<Map<String, dynamic>> webEvents = [];

  Future<Database> getDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite is not supported on web. Use webSessions/webEvents instead.');
    }
    if (_database != null) return _database!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    _database = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE distraction_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        package_name TEXT NOT NULL,
        app_label TEXT NOT NULL,
        triggered_at TEXT NOT NULL,
        recovered_at TEXT,
        recovery_time_seconds INTEGER,
        risk_score TEXT NOT NULL,
        event_type TEXT NOT NULL DEFAULT 'distraction',
        app_category TEXT,
        time_away_seconds INTEGER,
        risk_score_numeric REAL,
        was_notification_triggered INTEGER NOT NULL DEFAULT 0,
        returned_to_origin INTEGER NOT NULL DEFAULT 0,
        switch_stack_depth INTEGER,
        time_of_day_hour INTEGER,
        day_of_week INTEGER,
        session_minute_when_occurred INTEGER,
        is_recovered INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE focus_sessions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        productive_app TEXT NOT NULL,
        total_distractions INTEGER NOT NULL DEFAULT 0,
        total_xp_earned INTEGER NOT NULL DEFAULT 0,
        focus_score REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'active',
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE distraction_events ADD COLUMN event_type TEXT NOT NULL DEFAULT 'distraction'");
      await db.execute('ALTER TABLE distraction_events ADD COLUMN app_category TEXT');
      await db.execute('ALTER TABLE distraction_events ADD COLUMN time_away_seconds INTEGER');
      await db.execute('ALTER TABLE distraction_events ADD COLUMN risk_score_numeric REAL');
      await db.execute(
        'ALTER TABLE distraction_events ADD COLUMN was_notification_triggered INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE distraction_events ADD COLUMN returned_to_origin INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE distraction_events ADD COLUMN switch_stack_depth INTEGER');
      await db.execute('ALTER TABLE distraction_events ADD COLUMN time_of_day_hour INTEGER');
      await db.execute('ALTER TABLE distraction_events ADD COLUMN day_of_week INTEGER');
      await db.execute('ALTER TABLE distraction_events ADD COLUMN session_minute_when_occurred INTEGER');
    }
  }

  Future<void> close() async {
    if (kIsWeb) return;
    await _database?.close();
    _database = null;
  }

  Future<void> clearAllUserData() async {
    if (kIsWeb) {
      webSessions.clear();
      webEvents.clear();
      return;
    }
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.delete('distraction_events');
      await txn.delete('focus_sessions');
    });
  }
}
