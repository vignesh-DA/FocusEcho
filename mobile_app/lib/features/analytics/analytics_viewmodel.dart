import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_dependencies.dart';
import '../../local_db/focus_session_dao.dart';

class AnalyticsState {
  const AnalyticsState({
    this.weeklyFocusMinutes = const [0, 0, 0, 0, 0, 0, 0],
    this.dailyDistractions = const [0, 0, 0, 0, 0, 0, 0],
    this.appDistribution = const {},
    this.sessionScores = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final List<double> weeklyFocusMinutes;
  final List<int> dailyDistractions;
  final Map<String, int> appDistribution;
  final List<double> sessionScores;
  final bool isLoading;
  final String? errorMessage;

  AnalyticsState copyWith({
    List<double>? weeklyFocusMinutes,
    List<int>? dailyDistractions,
    Map<String, int>? appDistribution,
    List<double>? sessionScores,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AnalyticsState(
      weeklyFocusMinutes: weeklyFocusMinutes ?? this.weeklyFocusMinutes,
      dailyDistractions: dailyDistractions ?? this.dailyDistractions,
      appDistribution: appDistribution ?? this.appDistribution,
      sessionScores: sessionScores ?? this.sessionScores,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AnalyticsViewModel extends StateNotifier<AnalyticsState> {
  AnalyticsViewModel(this._sessionDao) : super(const AnalyticsState()) {
    loadAnalytics();
  }

  final FocusSessionDao _sessionDao;

  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final sessions = await _sessionDao.getSessionHistory(60);
      final now = DateTime.now();
      final weeklyFocus = List<double>.filled(7, 0);
      final dailyDistractions = List<int>.filled(7, 0);
      final appCount = <String, int>{};

      for (final s in sessions) {
        final dayIndex = 6 - now.difference(s.startTime).inDays;
        if (dayIndex >= 0 && dayIndex < 7) {
          weeklyFocus[dayIndex] += (s.endTime ?? now).difference(s.startTime).inMinutes.toDouble();
          dailyDistractions[dayIndex] += s.totalDistractions;
        }
        appCount[s.productiveApp] = (appCount[s.productiveApp] ?? 0) + s.totalDistractions;
      }

      state = state.copyWith(
        weeklyFocusMinutes: weeklyFocus,
        dailyDistractions: dailyDistractions,
        appDistribution: appCount,
        sessionScores: sessions.take(10).map((s) => s.focusScore).toList().reversed.toList(),
        isLoading: false,
      );
    } catch (e) {
      debugPrint('Analytics load error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load analytics. Pull to retry.',
      );
    }
  }
}

final analyticsProvider = StateNotifierProvider<AnalyticsViewModel, AnalyticsState>(
  (ref) => AnalyticsViewModel(AppDependencies.sessionDao),
);
