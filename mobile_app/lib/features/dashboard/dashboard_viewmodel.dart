import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/focus_session.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_dependencies.dart';
import '../../local_db/focus_session_dao.dart';
import '../../services/supabase_service.dart';

class DashboardState {
  const DashboardState({
    this.userProfile,
    this.todaySessions = const [],
    this.todayDistractionCount = 0,
    this.totalFocusMinutesToday = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserProfile? userProfile;
  final List<FocusSession> todaySessions;
  final int todayDistractionCount;
  final int totalFocusMinutesToday;
  final bool isLoading;
  final String? errorMessage;

  DashboardState copyWith({
    UserProfile? userProfile,
    List<FocusSession>? todaySessions,
    int? todayDistractionCount,
    int? totalFocusMinutesToday,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DashboardState(
      userProfile: userProfile ?? this.userProfile,
      todaySessions: todaySessions ?? this.todaySessions,
      todayDistractionCount: todayDistractionCount ?? this.todayDistractionCount,
      totalFocusMinutesToday: totalFocusMinutesToday ?? this.totalFocusMinutesToday,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel(this._supabaseService, this._focusSessionDao, this._userId)
      : super(const DashboardState()) {
    loadDashboard();
  }

  final SupabaseService _supabaseService;
  final FocusSessionDao _focusSessionDao;
  final String _userId;

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      UserProfile? profile;
      if (_supabaseService.currentUser != null) {
        try {
          profile = await _supabaseService.getUserProfile(_userId);
        } catch (e) {
          debugPrint('Could not fetch profile from Supabase: $e');
          // Continue with local data only
        }
      }

      final history = await _focusSessionDao.getSessionHistory(50);
      final today = DateTime.now();
      final todaySessions = history
          .where((s) =>
              s.startTime.year == today.year &&
              s.startTime.month == today.month &&
              s.startTime.day == today.day)
          .toList();

      final distractions = todaySessions.fold<int>(0, (sum, s) => sum + s.totalDistractions);
      final minutes = todaySessions.fold<int>(
        0,
        (sum, s) => sum + ((s.endTime ?? DateTime.now()).difference(s.startTime).inMinutes),
      );

      state = state.copyWith(
        userProfile: profile,
        todaySessions: todaySessions,
        todayDistractionCount: distractions,
        totalFocusMinutesToday: minutes,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Dashboard load error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load dashboard data. Pull to retry.',
      );
    }
  }
}

final dashboardProvider = StateNotifierProvider<DashboardViewModel, DashboardState>(
  (ref) => DashboardViewModel(
    AppDependencies.supabaseService,
    AppDependencies.sessionDao,
    AppDependencies.prefs.getString(AppKeys.userId) ??
        AppDependencies.prefs.getString(AppKeys.deviceId) ??
        '',
  ),
);
