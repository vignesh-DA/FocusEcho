import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/distraction_event.dart';
import '../../core/providers/app_dependencies.dart';
import '../../local_db/distraction_event_dao.dart';
import '../../local_db/focus_session_dao.dart';

/// Feature 3 — Recovery Rate definition (primary, used everywhere):
/// the % of distractions recovered within 30 seconds over a rolling window.
/// Median recovery time is shown as a supporting stat.
class RecoveryStats {
  const RecoveryStats({
    required this.rate,
    required this.medianRecoverySeconds,
    required this.sampleSize,
  });

  final double rate;
  final double medianRecoverySeconds;
  final int sampleSize;
}

class AnalyticsState {
  const AnalyticsState({
    this.weeklyFocusMinutes = const [0, 0, 0, 0, 0, 0, 0],
    this.dailyDistractions = const [0, 0, 0, 0, 0, 0, 0],
    this.appDistribution = const {},
    this.sessionScores = const [],
    this.recoveryRate = 0,
    this.medianRecoverySeconds = 0,
    this.recoveryRateTrend = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  final List<double> weeklyFocusMinutes;
  final List<int> dailyDistractions;
  final Map<String, int> appDistribution;
  final List<double> sessionScores;
  final double recoveryRate;
  final double medianRecoverySeconds;
  final double recoveryRateTrend;
  final bool isLoading;
  final String? errorMessage;

  AnalyticsState copyWith({
    List<double>? weeklyFocusMinutes,
    List<int>? dailyDistractions,
    Map<String, int>? appDistribution,
    List<double>? sessionScores,
    double? recoveryRate,
    double? medianRecoverySeconds,
    double? recoveryRateTrend,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AnalyticsState(
      weeklyFocusMinutes: weeklyFocusMinutes ?? this.weeklyFocusMinutes,
      dailyDistractions: dailyDistractions ?? this.dailyDistractions,
      appDistribution: appDistribution ?? this.appDistribution,
      sessionScores: sessionScores ?? this.sessionScores,
      recoveryRate: recoveryRate ?? this.recoveryRate,
      medianRecoverySeconds: medianRecoverySeconds ?? this.medianRecoverySeconds,
      recoveryRateTrend: recoveryRateTrend ?? this.recoveryRateTrend,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AnalyticsViewModel extends StateNotifier<AnalyticsState> {
  AnalyticsViewModel(this._sessionDao, this._eventDao) : super(const AnalyticsState()) {
    loadAnalytics();
  }

  final FocusSessionDao _sessionDao;
  final DistractionEventDao _eventDao;

  /// Primary Recovery Rate definition: % of distractions recovered < 30s.
  static const int _fastRecoveryThresholdSeconds = 30;

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

      // Feature 3 — Recovery Rate: rolling week vs. previous week.
      // 14 days of events covers both windows in a single query.
      final recentEvents = await _eventDao.getRecentEvents(14 * 24 * 60, eventType: 'distraction');
      final thisWeek = _recoveryStatsForWindow(recentEvents, now, const Duration(days: 7));
      final lastWeek = _recoveryStatsForWindow(
        recentEvents,
        now.subtract(const Duration(days: 7)),
        const Duration(days: 7),
      );
      final trend = thisWeek.rate - lastWeek.rate;

      state = state.copyWith(
        weeklyFocusMinutes: weeklyFocus,
        dailyDistractions: dailyDistractions,
        appDistribution: appCount,
        sessionScores: sessions.take(10).map((s) => s.focusScore).toList().reversed.toList(),
        recoveryRate: thisWeek.rate,
        medianRecoverySeconds: thisWeek.medianRecoverySeconds,
        recoveryRateTrend: trend,
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

  /// Computes RecoveryStats for distractions triggered within
  /// [now - window, now].
  RecoveryStats _recoveryStatsForWindow(
    List<DistractionEvent> events,
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

    if (total == 0) {
      return const RecoveryStats(rate: 0, medianRecoverySeconds: 0, sampleSize: 0);
    }
    final fast = recoveredSeconds
        .where((s) => s < _fastRecoveryThresholdSeconds)
        .length;
    final rate = (fast / total) * 100;
    final median = _median(recoveredSeconds);
    return RecoveryStats(
      rate: rate,
      medianRecoverySeconds: median,
      sampleSize: total,
    );
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

final analyticsProvider = StateNotifierProvider<AnalyticsViewModel, AnalyticsState>(
  (ref) => AnalyticsViewModel(AppDependencies.sessionDao, AppDependencies.eventDao),
);