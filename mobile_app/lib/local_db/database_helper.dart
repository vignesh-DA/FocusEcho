import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'focus_echo.db';
  static const _dbVersion = 4;

  Database? _database;

  // Web storage — backed by localStorage via SharedPreferences
  static final List<Map<String, dynamic>> webSessions = [];
  static final List<Map<String, dynamic>> webEvents = [];
  static final List<Map<String, dynamic>> webInterventions = [];
  static SharedPreferences? _webPrefs;
  static const _sessionsKey = 'focusecho_web_sessions';
  static const _eventsKey = 'focusecho_web_events';
  static const _interventionsKey = 'focusecho_web_interventions';

  /// Call once at startup on web to load persisted data from localStorage.
  static Future<void> initWebStorage(SharedPreferences prefs) async {
    if (!kIsWeb) return;
    _webPrefs = prefs;
    try {
      final sessionsJson = prefs.getString(_sessionsKey);
      if (sessionsJson != null) {
        final list = jsonDecode(sessionsJson) as List<dynamic>;
        webSessions.addAll(list.cast<Map<String, dynamic>>());
      }
      final eventsJson = prefs.getString(_eventsKey);
      if (eventsJson != null) {
        final list = jsonDecode(eventsJson) as List<dynamic>;
        webEvents.addAll(list.cast<Map<String, dynamic>>());
      }
      final interventionsJson = prefs.getString(_interventionsKey);
      if (interventionsJson != null) {
        final list = jsonDecode(interventionsJson) as List<dynamic>;
        webInterventions.addAll(list.cast<Map<String, dynamic>>());
      }
    } catch (e) {
      debugPrint('[WebStorage] Failed to load from localStorage: $e');
    }
  }

  /// Persist both lists to localStorage. Call after every web mutation.
  static Future<void> persistWeb() async {
    if (!kIsWeb || _webPrefs == null) return;
    try {
      await _webPrefs!.setString(_sessionsKey, jsonEncode(webSessions));
      await _webPrefs!.setString(_eventsKey, jsonEncode(webEvents));
      await _webPrefs!.setString(_interventionsKey, jsonEncode(webInterventions));
    } catch (e) {
      debugPrint('[WebStorage] Failed to persist to localStorage: $e');
    }
  }

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
        escalation_level INTEGER NOT NULL DEFAULT 1,
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
        intent TEXT NOT NULL DEFAULT '',
        total_distractions INTEGER NOT NULL DEFAULT 0,
        total_xp_earned INTEGER NOT NULL DEFAULT 0,
        focus_score REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'active',
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE intervention_events (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        level INTEGER NOT NULL,
        action_taken TEXT NOT NULL,
        timestamp TEXT NOT NULL,
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
    if (oldVersion < 3) {
      // Feature 1 — Focus Intent: every session carries a stated goal.
      await db.execute("ALTER TABLE focus_sessions ADD COLUMN intent TEXT NOT NULL DEFAULT ''");
      // Feature 2 — Escalating Intervention log.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS intervention_events (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          level INTEGER NOT NULL,
          action_taken TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          is_synced INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 4) {
      // Feature 2 — escalation ladder level on every distraction event
      // (mirrors the Supabase escalation_level column).
      await db.execute(
        'ALTER TABLE distraction_events ADD COLUMN escalation_level INTEGER NOT NULL DEFAULT 1',
      );
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
      webInterventions.clear();
      await persistWeb();
      return;
    }
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.delete('distraction_events');
      await txn.delete('focus_sessions');
      await txn.delete('intervention_events');
    });
  }
}
