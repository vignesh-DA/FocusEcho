import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/distraction_event.dart';
import '../core/models/focus_session.dart';
import '../core/models/intervention_event.dart';
import '../core/models/user_profile.dart';
import '../core/constants/app_constants.dart';

class SupabaseService {
  SupabaseService({SupabaseClient? client}) : _client = client ?? _tryClient();

  final SupabaseClient? _client;
  RealtimeChannel? _interventionChannel;

  static SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Upsert using snake_case keys matching the Supabase schema.
  /// Previously used `event.toJson()` which produces camelCase (Freezed default),
  /// causing silent column mismatches.
  Future<void> upsertDistractionEvent(DistractionEvent event) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Cloud sync is unavailable or unauthenticated.');
    }
    final map = Map<String, dynamic>.from(event.toSqliteMap());
    await client.from('distraction_events').upsert(map);
  }

  Future<bool> upsertFocusSession(FocusSession session) async {
    final client = _client;
    final authUserId = client?.auth.currentUser?.id;
    if (client == null || authUserId == null) return false;
    final row = session.toSqliteMap()..['user_id'] = authUserId;
    final parked = row['parked_items'];
    if (parked is String) {
      try {
        row['parked_items'] = jsonDecode(parked);
      } catch (_) {
        row['parked_items'] = null;
      }
    }
    try {
      await client.from('focus_sessions').upsert(row);
      return true;
    } on PostgrestException catch (error) {
      // A deployment that has not run the Batch 1 migration must still be
      // usable. Retry the legacy row, but keep the local row unsynced so the
      // new fields are retried after the migration is applied.
      final message = error.message.toLowerCase();
      if (!message.contains('focus_rating') &&
          !message.contains('drift_reason') &&
          !message.contains('parked_items') &&
          !message.contains('schema cache')) {
        rethrow;
      }
      final legacy = Map<String, dynamic>.from(row)
        ..remove('focus_rating')
        ..remove('drift_reason')
        ..remove('parked_items');
      await client.from('focus_sessions').upsert(legacy);
      return false;
    }
  }

  Future<void> upsertInterventionEvent(InterventionEvent event) async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) {
      throw StateError('Cloud sync is unavailable or unauthenticated.');
    }
    await client.from('intervention_events').upsert(event.toSqliteMap());
  }

  // ── Feature 4 — Cross-Surface Intervention Sync ──────────────────────────
  // A Supabase Realtime broadcast channel keyed by the signed-in user id.
  // Both surfaces (phone + browser) of the same account subscribe; a
  // distraction on one surface nudges the other within seconds.

  /// Publishes a lightweight distraction nudge on the user's channel.
  Future<void> broadcastDistraction(
    String userId, {
    required String surface,
    required String label,
    required int level,
  }) async {
    final client = _client;
    if (client == null || client.auth.currentUser?.id != userId) return;
    final channel = client.channel('focusecho-interventions:$userId');
    await channel.sendBroadcastMessage(
      event: 'distraction',
      payload: {
        'surface': surface,
        'host_or_app': label,
        'escalation_level': level,
        'sent_at': DateTime.now().toIso8601String(),
      },
    );
    // Broadcast channels are ephemeral here — remove after send so repeated
    // broadcasts don't accumulate channels.
    await client.removeChannel(channel);
  }

  /// Subscribes to cross-surface nudges. [onNudge] receives
  /// (surface, hostOrApp, escalationLevel) for events originating on the
  /// *other* surface.
  Future<void> subscribeToInterventions(
    String userId,
    void Function(String surface, String hostOrApp, int level) onNudge,
  ) async {
    unsubscribeFromInterventions();
    final client = _client;
    if (client == null || client.auth.currentUser?.id != userId) return;
    const mySurface = kIsWeb ? 'browser' : 'phone';
    final channel = client.channel('focusecho-interventions:$userId');
    channel.onBroadcast(
      event: 'distraction',
      callback: (payload) {
        final surface = payload['surface']?.toString() ?? 'unknown';
        if (surface == mySurface) return; // ignore our own broadcasts
        onNudge(
          surface,
          payload['host_or_app']?.toString() ?? 'something',
          (payload['escalation_level'] as num?)?.toInt() ?? 1,
        );
      },
    );
    channel.subscribe();
    _interventionChannel = channel;
  }

  void unsubscribeFromInterventions() {
    final channel = _interventionChannel;
    final client = _client;
    if (channel != null && client != null) {
      client.removeChannel(channel);
      _interventionChannel = null;
    }
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    final client = _client;
    if (client == null || client.auth.currentUser?.id != userId) return null;
    final row =
        await client.from('users').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  Future<void> updateUserXP(String userId, int totalXp, int streakDays) async {
    final client = _client;
    final authUserId = client?.auth.currentUser?.id;
    if (client == null || authUserId == null || authUserId != userId) return;
    await client.from('user_xp').upsert({
      'user_id': authUserId,
      'total_xp': totalXp,
      'streak_days': streakDays,
    });
  }

  /// Pulls the account's shared app/site lists into the local offline cache.
  /// If this is the first device for the account, uploads the current local
  /// settings as the initial shared copy. Cloud sync opt-out is respected.
  Future<void> loadOrSeedFocusPreferences(SharedPreferences prefs) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null ||
        userId == null ||
        prefs.getBool(AppKeys.localOnlyMode) == true ||
        prefs.getBool(AppKeys.syncEnabled) == false) {
      return;
    }

    try {
      final row = await client
          .from('user_focus_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        await syncFocusPreferencesFromPrefs(prefs);
        return;
      }
      await prefs.setString(AppKeys.productiveApps,
          jsonEncode(row['productive_apps'] ?? const []));
      await prefs.setString(AppKeys.distractingApps,
          jsonEncode(row['distracting_apps'] ?? const []));
      await prefs.setString(AppKeys.webDistractingSites,
          jsonEncode(row['web_distracting_sites'] ?? const []));
      await prefs.setString(AppKeys.appTimeLimitsSeconds,
          jsonEncode(row['app_time_limits_seconds'] ?? const {}));
    } catch (error) {
      debugPrint('[Sync] Focus preferences unavailable: ${error.runtimeType}');
    }
  }

  /// Persists the local cache to the account row after a settings change.
  Future<void> syncFocusPreferencesFromPrefs(SharedPreferences prefs) async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;
    if (client == null ||
        userId == null ||
        prefs.getBool(AppKeys.localOnlyMode) == true ||
        prefs.getBool(AppKeys.syncEnabled) == false) {
      return;
    }
    dynamic decode(String key, dynamic fallback) {
      try {
        return jsonDecode(prefs.getString(key) ?? jsonEncode(fallback));
      } catch (_) {
        return fallback;
      }
    }

    try {
      await client.from('user_focus_preferences').upsert({
        'user_id': userId,
        'productive_apps': decode(AppKeys.productiveApps, const []),
        'distracting_apps': decode(AppKeys.distractingApps, const []),
        'web_distracting_sites': decode(AppKeys.webDistractingSites, const []),
        'app_time_limits_seconds':
            decode(AppKeys.appTimeLimitsSeconds, const {}),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (error) {
      // Keep local settings usable while offline; the next settings change or
      // authenticated startup retries the upload.
      debugPrint(
          '[Sync] Focus preferences upload failed: ${error.runtimeType}');
    }
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  Future<void> deleteCurrentUserData() async {
    final client = _client;
    if (client == null) {
      throw StateError('Cloud service is unavailable.');
    }
    final user = client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user found.');
    }

    String? targetUserId = user.id;
    final userById =
        await client.from('users').select('id').eq('id', user.id).maybeSingle();
    if (userById == null && user.email != null) {
      final userByEmail = await client
          .from('users')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();
      if (userByEmail != null) {
        targetUserId = userByEmail['id'] as String;
      } else {
        targetUserId = null;
      }
    }

    if (targetUserId != null) {
      final sessionRows = await client
          .from('focus_sessions')
          .select('id')
          .eq('user_id', targetUserId) as List;
      final sessionIds = sessionRows.map((row) => row['id'] as String).toList();
      if (sessionIds.isNotEmpty) {
        await client
            .from('distraction_events')
            .delete()
            .inFilter('session_id', sessionIds);
        await client
            .from('coach_insights')
            .delete()
            .inFilter('session_id', sessionIds);
      }

      await client.from('coach_insights').delete().eq('user_id', targetUserId);
      await client.from('coach_profiles').delete().eq('user_id', targetUserId);
      try {
        await client
            .from('user_focus_preferences')
            .delete()
            .eq('user_id', targetUserId);
      } on PostgrestException catch (error) {
        final message = error.message.toLowerCase();
        final preferenceSchemaMissing =
            message.contains('user_focus_preferences') &&
                (message.contains('schema cache') ||
                    message.contains('does not exist'));
        if (!preferenceSchemaMissing) rethrow;
        debugPrint(
            '[Privacy] Shared settings table not deployed yet; no cloud row to remove.');
      }
      await client.from('focus_sessions').delete().eq('user_id', targetUserId);
      await client
          .from('nightly_analytics_summaries')
          .delete()
          .eq('user_id', targetUserId);
      await client.from('user_xp').delete().eq('user_id', targetUserId);
      await client.from('users').delete().eq('id', targetUserId);
    }

    await client.auth.signOut();
  }

  User? get currentUser => _client?.auth.currentUser;
  Session? get currentSession => _client?.auth.currentSession;

  /// Returns a broadcast stream of distraction_events rows for [sessionId].
  /// Updates are delivered via Supabase Realtime without polling.
  Stream<List<Map<String, dynamic>>> watchDistractionEvents(String sessionId) {
    final client = _client;
    if (client == null || client.auth.currentUser == null) {
      return const Stream.empty();
    }
    return client
        .from('distraction_events')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('triggered_at', ascending: false);
  }
}
