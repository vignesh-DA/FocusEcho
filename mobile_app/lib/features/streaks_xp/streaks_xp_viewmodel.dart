import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_dependencies.dart';
import '../../local_db/focus_session_dao.dart';
import '../../services/supabase_service.dart';

class StreaksXpState {
  const StreaksXpState({
    this.userProfile,
    this.weeklyActivity = const [
      false,
      false,
      false,
      false,
      false,
      false,
      false
    ],
    this.xpToNextLevel = 0,
    this.progressPercent = 0,
    this.errorMessage,
    this.totalXp = 0,
    this.streakDays = 0,
  });

  final UserProfile? userProfile;
  final List<bool> weeklyActivity;
  final int xpToNextLevel;
  final double progressPercent;
  final String? errorMessage;
  final int totalXp;
  final int streakDays;

  StreaksXpState copyWith({
    UserProfile? userProfile,
    List<bool>? weeklyActivity,
    int? xpToNextLevel,
    double? progressPercent,
    String? errorMessage,
    int? totalXp,
    int? streakDays,
  }) {
    return StreaksXpState(
      userProfile: userProfile ?? this.userProfile,
      weeklyActivity: weeklyActivity ?? this.weeklyActivity,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      progressPercent: progressPercent ?? this.progressPercent,
      errorMessage: errorMessage,
      totalXp: totalXp ?? this.totalXp,
      streakDays: streakDays ?? this.streakDays,
    );
  }
}

class StreaksXpViewModel extends StateNotifier<StreaksXpState> {
  StreaksXpViewModel(this._supabaseService, this._sessionDao, this._userId)
      : super(const StreaksXpState()) {
    loadStreaks();
    try {
      if (_supabaseService.currentUser != null) {
        _xpChannel = Supabase.instance.client
            .channel('user-xp-$_userId')
            .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'user_xp',
                callback: (_) => loadStreaks())
            .subscribe();
      }
    } catch (error) {
      debugPrint('XP realtime unavailable: ${error.runtimeType}');
    }
  }

  final SupabaseService _supabaseService;
  final FocusSessionDao _sessionDao;
  final String _userId;
  RealtimeChannel? _xpChannel;

  Future<void> loadStreaks() async {
    try {
      UserProfile? profile;
      if (_supabaseService.currentUser != null) {
        try {
          profile = await _supabaseService.getUserProfile(_userId);
        } catch (e) {
          debugPrint('Could not fetch profile for streaks: $e');
        }
      }

      var effectiveXp = AppDependencies.prefs.getInt(AppKeys.xpTotal) ??
          profile?.totalXp ??
          0;
      var effectiveStreak = AppDependencies.prefs.getInt(AppKeys.streakDays) ??
          profile?.streakDays ??
          0;
      if (_userId.isNotEmpty) {
        try {
          final xpRow = await Supabase.instance.client
              .from('user_xp')
              .select()
              .eq('user_id', _userId)
              .maybeSingle();
          if (xpRow != null) {
            effectiveXp = (xpRow['total_xp'] as num?)?.toInt() ?? effectiveXp;
            effectiveStreak =
                (xpRow['streak_days'] as num?)?.toInt() ?? effectiveStreak;
          }
        } catch (e) {
          debugPrint('XP query failed: $e');
        }
      }
      if (profile != null) {
        profile =
            profile.copyWith(totalXp: effectiveXp, streakDays: effectiveStreak);
      }

      final sessions = await _sessionDao.getSessionHistory(100);
      final now = DateTime.now();
      final weekly = List<bool>.generate(7, (idx) {
        final day = now.subtract(Duration(days: 6 - idx));
        return sessions.any(
          (s) =>
              s.startTime.year == day.year &&
              s.startTime.month == day.month &&
              s.startTime.day == day.day,
        );
      });
      state = state.copyWith(
          userProfile: profile,
          weeklyActivity: weekly,
          totalXp: effectiveXp,
          streakDays: effectiveStreak,
          errorMessage: null);
      computeXpProgress();
    } catch (e) {
      debugPrint('Streaks load error: $e');
      state = state.copyWith(errorMessage: 'Could not load streaks data.');
    }
  }

  void computeXpProgress() {
    final xp = state.totalXp;
    int nextThreshold = AppXP.level2Min;
    int baseThreshold = 0;
    if (xp >= AppXP.level4Min) {
      nextThreshold = AppXP.level4Min;
      baseThreshold = AppXP.level4Min;
    } else if (xp >= AppXP.level3Min) {
      nextThreshold = AppXP.level4Min;
      baseThreshold = AppXP.level3Min;
    } else if (xp >= AppXP.level2Min) {
      nextThreshold = AppXP.level3Min;
      baseThreshold = AppXP.level2Min;
    }
    final span = (nextThreshold - baseThreshold).clamp(1, 100000);
    state = state.copyWith(
      xpToNextLevel: (nextThreshold - xp).clamp(0, nextThreshold),
      progressPercent: ((xp - baseThreshold) / span).clamp(0, 1),
    );
  }

  @override
  void dispose() {
    final channel = _xpChannel;
    if (channel != null) {
      try {
        Supabase.instance.client.removeChannel(channel);
      } catch (_) {
        // No cloud channel exists in offline mode.
      }
    }
    super.dispose();
  }
}

final streaksXpProvider =
    StateNotifierProvider<StreaksXpViewModel, StreaksXpState>(
  (ref) => StreaksXpViewModel(
    AppDependencies.supabaseService,
    AppDependencies.sessionDao,
    AppDependencies.supabaseService.currentUser?.id ??
        AppDependencies.prefs.getString(AppKeys.userId) ??
        '',
  ),
);
