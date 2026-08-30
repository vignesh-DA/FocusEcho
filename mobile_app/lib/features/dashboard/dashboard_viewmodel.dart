import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/focus_session.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_dependencies.dart';
import '../../local_db/distraction_event_dao.dart';
import '../../local_db/focus_session_dao.dart';
import '../../services/supabase_service.dart';

class DashboardState {
  const DashboardState({
    this.userProfile,
    this.todaySessions = const [],
    this.todayDistractionCount = 0,
    this.totalFocusMinutesToday = 0,
    this.recoveryRate = 0,
    this.recoveryRateTrend = 0,
    this.medianRecoverySeconds = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserProfile? userProfile;
  final List<FocusSession> todaySessions;
  final int todayDistractionCount;
  final int totalFocusMinutesToday;
  final double recoveryRate;
  final double recoveryRateTrend;
  final double medianRecoverySeconds;
  final bool isLoading;
  final String? errorMessage;

  DashboardState copyWith({
    UserProfile? userProfile,
    List<FocusSession>? todaySessions,
    int? todayDistractionCount,
    int? totalFocusMinutesToday,
    double? recoveryRate,
    double? recoveryRateTrend,
    double? medianRecoverySeconds,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DashboardState(
      userProfile: userProfile ?? this.userProfile,
      todaySessions: todaySessions ?? this.todaySessions,
      todayDistractionCount: todayDistractionCount ?? this.todayDistractionCount,
      totalFocusMinutesToday: totalFocusMinutesToday ?? this.totalFocusMinutesToday,
      recoveryRate: recoveryRate ?? this.recoveryRate,
      recoveryRateTrend: recoveryRateTrend ?? this.recoveryRateTrend,
      medianRecoverySeconds: medianRecoverySeconds ?? this.medianRecoverySeconds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel(this._supabaseService, this._focusSessionDao, this._eventDao, this._userId)
      : super(const DashboardState()) {
    loadDashboard();
  }

  final SupabaseService _supabaseService;
  final FocusSessionDao _focusSessionDao;
  final DistractionEventDao _eventDao;
  final String _userId;

  /// Feature 3 — same primary definition as analytics:
  /// % of distractions recovered within 30 seconds, rolling week,
  /// with a week-over-week trend.
  static const int _fastRecoveryThresholdSeconds = 30;

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

      // Feature 3 — headline Recovery Rate with week-over-week trend.
      final now = DateTime.now();
      final recentEvents = await _eventDao.getRecentEvents(14 * 24 * 60, eventType: 'distraction');
      final thisWeek = _recoveryStatsForWindow(recentEvents, now, const Duration(days: 7));
      final lastWeek = _recoveryStatsForWindow(
        recentEvents,
        now.subtract(const Duration(days: 7)),
        const Duration(days: 7),
      );

      state = state.copyWith(
        userProfile: profile,
        todaySessions: todaySessions,
        todayDistractionCount: distractions,
        totalFocusMinutesToday: minutes,
        recoveryRate: thisWeek.rate,
        recoveryRateTrend: thisWeek.rate - lastWeek.rate,
        medianRecoverySeconds: thisWeek.median,
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

  ({double rate, double median}) _recoveryStatsForWindow(
    List<dynamic> events,
    DateTime now,
    Duration window,
  ) {
    final cutoff = now.subtract(window);
    final recoveredSeconds = <double>[];
    var total = 0;

    for (final event in events) {
      if (event.eventType != 'distraction') continue;
      if (event.triggeredAt.isBefore(cutoff)) continue;
      total++;
      final seconds = event.recoveryTimeSeconds;
      if (event.isRecovered && seconds != null) {
        recoveredSeconds.add(seconds.toDouble());
      }
    }

    if (total == 0) return (rate: 0.0, median: 0.0);
    final fast = recoveredSeconds.where((s) => s < _fastRecoveryThresholdSeconds).length;
    final sorted = List<double>.from(recoveredSeconds)..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.isEmpty
        ? 0.0
        : (sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2);
    return (rate: (fast / total) * 100, median: median);
  }
}

final dashboardProvider = StateNotifierProvider<DashboardViewModel, DashboardState>(
  (ref) => DashboardViewModel(
    AppDependencies.supabaseService,
    AppDependencies.sessionDao,
    AppDependencies.eventDao,
    AppDependencies.prefs.getString(AppKeys.userId) ??
        AppDependencies.prefs.getString(AppKeys.deviceId) ??
        '',
  ),
);