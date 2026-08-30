import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/models/distraction_event.dart';
import '../core/models/focus_session.dart';
import '../core/models/user_profile.dart';

class SupabaseService {
  SupabaseService() : _client = Supabase.instance.client;

  final SupabaseClient _client;

  /// Upsert using snake_case keys matching the Supabase schema.
  /// Previously used `event.toJson()` which produces camelCase (Freezed default),
  /// causing silent column mismatches.
  Future<void> upsertDistractionEvent(DistractionEvent event) async {
    await _client.from('distraction_events').upsert(event.toSqliteMap());
  }

  Future<void> upsertFocusSession(FocusSession session) async {
    await _client.from('focus_sessions').upsert(session.toSqliteMap());
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
