import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/distraction_event.dart';
import '../core/models/focus_session.dart';
import '../core/models/intervention_event.dart';
import '../core/models/user_profile.dart';

class SupabaseService {
  SupabaseService() : _client = Supabase.instance.client;

  final SupabaseClient _client;
  RealtimeChannel? _interventionChannel;

  /// Upsert using snake_case keys matching the Supabase schema.
  /// Previously used `event.toJson()` which produces camelCase (Freezed default),
  /// causing silent column mismatches.
  Future<void> upsertDistractionEvent(DistractionEvent event) async {
    await _client.from('distraction_events').upsert(event.toSqliteMap());
  }

  Future<void> upsertFocusSession(FocusSession session) async {
    await _client.from('focus_sessions').upsert(session.toSqliteMap());
  }

  Future<void> upsertInterventionEvent(InterventionEvent event) async {
    await _client.from('intervention_events').upsert(event.toSqliteMap());
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
    final channel = _client.channel('focusecho-interventions:$userId');
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
    await _client.removeChannel(channel);
  }

  /// Subscribes to cross-surface nudges. [onNudge] receives
  /// (surface, hostOrApp, escalationLevel) for events originating on the
  /// *other* surface.
  Future<void> subscribeToInterventions(
    String userId,
    void Function(String surface, String hostOrApp, int level) onNudge,
  ) async {
    unsubscribeFromInterventions();
    const mySurface = kIsWeb ? 'browser' : 'phone';
    final channel = _client.channel('focusecho-interventions:$userId');
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
    if (channel != null) {
      _client.removeChannel(channel);
      _interventionChannel = null;
    }
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    final row =
        await _client.from('users').select().eq('id', userId).maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(row);
  }

  Future<void> updateUserXP(String userId, int totalXp, int streakDays) async {
    await _client.from('user_xp').upsert({
      'user_id': userId,
      'total_xp': totalXp,
      'streak_days': streakDays,
    });
  }

  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'com.focusecho.ai://login-callback',
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> deleteCurrentUserData() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user found.');
    }

    String? targetUserId = user.id;
    final userById = await _client.from('users').select('id').eq('id', user.id).maybeSingle();
    if (userById == null && user.email != null) {
      final userByEmail =
          await _client.from('users').select('id').eq('email', user.email!).maybeSingle();
      if (userByEmail != null) {
        targetUserId = userByEmail['id'] as String;
      } else {
        targetUserId = null;
      }
    }

    if (targetUserId != null) {
      final sessionRows =
          await _client.from('focus_sessions').select('id').eq('user_id', targetUserId) as List;
      final sessionIds = sessionRows.map((row) => row['id'] as String).toList();
      if (sessionIds.isNotEmpty) {
        await _client.from('distraction_events').delete().inFilter('session_id', sessionIds);
      }

      await _client.from('focus_sessions').delete().eq('user_id', targetUserId);
      await _client.from('nightly_analytics_summaries').delete().eq('user_id', targetUserId);
      await _client.from('user_xp').delete().eq('user_id', targetUserId);
      await _client.from('users').delete().eq('id', targetUserId);
    }

    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
}
