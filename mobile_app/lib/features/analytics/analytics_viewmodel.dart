import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/distraction_event.dart';
import '../../core/models/focus_session.dart';
import '../../core/providers/app_dependencies.dart';
import '../../local_db/distraction_event_dao.dart';
import '../../local_db/focus_session_dao.dart';
import '../../services/backend_analytics_service.dart';
import '../../core/utils/fe_logger.dart';

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
    // MOB-3g — remote backend enrichment fields
    this.remoteFocusScoreAverage,
    this.remoteWeeklySessions,
    this.remoteTopApps = const [],
    this.remoteRiskTrend = const [],
    this.isRemoteLoaded = false,
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

  // MOB-3g — enriched from FastAPI backend (null = not yet fetched / offline)
  final double? remoteFocusScoreAverage;
  final int? remoteWeeklySessions;
  final List<TopApp> remoteTopApps;
  final List<RiskDayEntry> remoteRiskTrend;
  final bool isRemoteLoaded;

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
    double? remoteFocusScoreAverage,
    int? remoteWeeklySessions,
    List<TopApp>? remoteTopApps,
    List<RiskDayEntry>? remoteRiskTrend,
    bool? isRemoteLoaded,
  }) {
    return AnalyticsState(
      weeklyFocusMinutes: weeklyFocusMinutes ?? this.weeklyFocusMinutes,
      dailyDistractions: dailyDistractions ?? this.dailyDistractions,
      appDistribution: appDistribution ?? this.appDistribution,
      sessionScores: sessionScores ?? this.sessionScores,
      recoveryRate: recoveryRate ?? this.recoveryRate,
      medianRecoverySeconds:
          medianRecoverySeconds ?? this.medianRecoverySeconds,
      recoveryRateTrend: recoveryRateTrend ?? this.recoveryRateTrend,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      remoteFocusScoreAverage:
          remoteFocusScoreAverage ?? this.remoteFocusScoreAverage,
      remoteWeeklySessions: remoteWeeklySessions ?? this.remoteWeeklySessions,
      remoteTopApps: remoteTopApps ?? this.remoteTopApps,
      remoteRiskTrend: remoteRiskTrend ?? this.remoteRiskTrend,
      isRemoteLoaded: isRemoteLoaded ?? this.isRemoteLoaded,
    );
  }
}

class AnalyticsViewModel extends StateNotifier<AnalyticsState> {
  AnalyticsViewModel(
    this._sessionDao,
    this._eventDao,
    this._backendAnalytics,
  ) : super(const AnalyticsState()) {
    loadAnalytics();
  }

  final FocusSessionDao _sessionDao;
  final DistractionEventDao _eventDao;
  final BackendAnalyticsService _backendAnalytics;

  /// Primary Recovery Rate definition: % of distractions recovered < 30s.
  static const int _fastRecoveryThresholdSeconds = 30;

  /// MOB-3g: loads local SQLite data first (fast), then fetches remote backend
  /// data in parallel. The remote call is best-effort — failure is logged and
  /// the screen stays fully functional with local data.
  /// Conflict Resolution: If an id exists in both Cloud and Local,
  /// prefer the version that has endTime != null or the greater duration / latest timestamp.
  FocusSession _resolveSessionConflict(FocusSession a, FocusSession b) {
    if (a.endTime != null && b.endTime == null) return a;
    if (b.endTime != null && a.endTime == null) return b;
    final durA = (a.endTime ?? a.startTime).difference(a.startTime);
    final durB = (b.endTime ?? b.startTime).difference(b.startTime);
    if (durA > durB) return a;
    if (durB > durA) return b;
    if (a.focusScore > b.focusScore) return a;
    if (b.focusScore > a.focusScore) return b;
    return a;
  }

  /// Conflict Resolution: prefer the version that is recovered or has greater recoveryTimeSeconds.
  DistractionEvent _resolveEventConflict(
      DistractionEvent a, DistractionEvent b) {
    if (a.isRecovered && !b.isRecovered) return a;
    if (b.isRecovered && !a.isRecovered) return b;
    if ((a.recoveryTimeSeconds ?? 0) > (b.recoveryTimeSeconds ?? 0)) return a;
    if ((b.recoveryTimeSeconds ?? 0) > (a.recoveryTimeSeconds ?? 0)) return b;
    return a;
  }

  /// Unified fetch & merge of sessions from Supabase and local cache.
  Future<List<FocusSession>> _loadUnifiedSessions() async {
    final cloudSessions = <FocusSession>[];
    try {
      // Use UTC so the cutoff matches Supabase's timestamptz storage,
      // preventing sessions recorded in +5:30 or any other offset from
      // being silently dropped by an off-by-hours comparison.
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 7))
          .toIso8601String();
      final rows = await Supabase.instance.client
          .from('focus_sessions')
          .select()
          .gte('start_time', cutoff)
          .order('start_time', ascending: false);
      cloudSessions.addAll((rows as List).map((row) =>
          FocusSession.fromSqliteMap(Map<String, dynamic>.from(row as Map))));
      FELog.d('Analytics',
          'Cloud query: fetched ${cloudSessions.length} sessions (since $cutoff)');
    } catch (e) {
      FELog.w('Analytics',
          'Cloud session query failed (continuing with local cache): $e');
    }

    // Always query local cache — it is the definitive source on Android
    // and a write-through cache on web.
    final localSessions = <FocusSession>[];
    try {
      localSessions.addAll(await _sessionDao.getSessionHistory(60));
    } catch (e) {
      FELog.w('Analytics', 'Local session cache query failed: $e');
    }

    // Merge into Map keyed by id with conflict resolution
    final sessionMap = <String, FocusSession>{};
    for (final s in cloudSessions) {
      sessionMap[s.id] = s;
    }
    for (final s in localSessions) {
      if (sessionMap.containsKey(s.id)) {
        sessionMap[s.id] = _resolveSessionConflict(sessionMap[s.id]!, s);
      } else {
        sessionMap[s.id] = s;
      }
    }

    final merged = sessionMap.values.toList();
    merged.sort((a, b) => b.startTime.compareTo(a.startTime));
    return merged;
  }

  /// Unified fetch & merge of distraction events from Supabase and local cache.
  Future<List<DistractionEvent>> _loadUnifiedEvents() async {
    final cloudEvents = <DistractionEvent>[];
    // UTC cutoff to match Supabase timestamptz
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 7));
    try {
      final rows = await Supabase.instance.client
          .from('distraction_events')
          .select()
          .gte('triggered_at', cutoff.toIso8601String())
          .order('triggered_at', ascending: false);
      cloudEvents.addAll((rows as List)
          .map((row) => DistractionEvent.fromSqliteMap(
              Map<String, dynamic>.from(row as Map)))
          .where((e) => e.eventType == 'distraction'));
      FELog.d('Analytics',
          'Cloud query: fetched ${cloudEvents.length} distraction events');
    } catch (e) {
      FELog.w('Analytics', 'Cloud event query failed: $e');
    }

    // Always query local cache
    final localEvents = <DistractionEvent>[];
    try {
      localEvents.addAll(
          await _eventDao.getRecentEvents(200, eventType: 'distraction'));
    } catch (e) {
      FELog.w('Analytics', 'Local event cache query failed: $e');
    }

    final eventMap = <String, DistractionEvent>{};
    for (final e in cloudEvents) {
      eventMap[e.id] = e;
    }
    for (final e in localEvents) {
      if (eventMap.containsKey(e.id)) {
        eventMap[e.id] = _resolveEventConflict(eventMap[e.id]!, e);
      } else {
        eventMap[e.id] = e;
      }
    }

    final merged = eventMap.values
        .where((e) => e.eventType == 'distraction')
        .toList();
    merged.sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return merged;
  }

  /// MOB-3g: loads unified local + cloud data, then fetches remote backend
  /// data in parallel. The remote call is best-effort — failure is logged and
  /// the screen stays fully functional with local data.
  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    FELog.i('Analytics', 'Starting loadAnalytics computation');
    try {
      // ── Bug 1: Unified Cloud + Local merge ──────────────────────────────
      final sessions = await _loadUnifiedSessions();
      final recentEvents = await _loadUnifiedEvents();

      // ── Bug 2: Calendar-Midnight Normalization ──────────────────────────
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final weeklyFocus = List<double>.filled(7, 0);
      final dailyDistractions = List<int>.filled(7, 0);
      final appCount = <String, int>{};

      for (final s in sessions) {
        final itemMidnight =
            DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
        final daysAgo = todayMidnight.difference(itemMidnight).inDays;
        final dayIndex = 6 - daysAgo;
        if (dayIndex >= 0 && dayIndex < 7) {
          weeklyFocus[dayIndex] +=
              (s.endTime ?? now).difference(s.startTime).inMinutes.toDouble();
        }
      }

      for (final e in recentEvents) {
        final itemMidnight = DateTime(
            e.triggeredAt.year, e.triggeredAt.month, e.triggeredAt.day);
        final daysAgo = todayMidnight.difference(itemMidnight).inDays;
        final dayIndex = 6 - daysAgo;
        if (dayIndex >= 0 && dayIndex < 7) {
          dailyDistractions[dayIndex] += 1;
        }
        final label = e.appLabel.isNotEmpty ? e.appLabel : e.packageName;
        appCount[label] = (appCount[label] ?? 0) + 1;
      }

      final thisWeek =
          _recoveryStatsForWindow(recentEvents, now, const Duration(days: 7));
      final lastWeek = _recoveryStatsForWindow(
        recentEvents,
        now.subtract(const Duration(days: 7)),
        const Duration(days: 7),
      );
      final trend = thisWeek.rate - lastWeek.rate;

      FELog.i(
        'Analytics',
        'Analytics calculated: ${sessions.length} sessions, ${recentEvents.length} events, '
            'weeklyFocusSum=${weeklyFocus.reduce((a, b) => a + b).toInt()}m, '
            'recoveryRate=${thisWeek.rate.toStringAsFixed(1)}%, topApps=${appCount.keys.length}',
      );

      // ── Bug 3: Take 10 most recent completed sessions, then reverse for left-to-right chronological order
      final completed = sessions
          .where((s) => s.endTime != null || s.status == SessionStatus.completed)
          .toList();
      final scoreSessions = completed.isNotEmpty ? completed : sessions;

      state = state.copyWith(
        weeklyFocusMinutes: weeklyFocus,
        dailyDistractions: dailyDistractions,
        appDistribution: appCount,
        sessionScores: scoreSessions
            .take(10)
            .map((s) => s.focusScore)
            .toList()
            .reversed
            .toList(),
        recoveryRate: thisWeek.rate,
        medianRecoverySeconds: thisWeek.medianRecoverySeconds,
        recoveryRateTrend: trend,
        isLoading: false,
      );

      // ── Remote backend (MOB-3g) — fire-and-forget enrichment ─────────────
      unawaited(_loadRemote());
    } catch (e, st) {
      FELog.e('Analytics', 'Analytics load failed', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Could not load analytics. Pull to retry.',
      );
    }
  }

  /// Fetches backend summary + risk-trend and merges into state.
  /// Runs after local data is already displayed; failure is silent.
  Future<void> _loadRemote() async {
    // Retrieve Supabase session JWT as the Bearer token for the FastAPI backend.
    final session = AppDependencies.supabaseService.currentSession;
    if (session == null) {
      FELog.d(
          'Analytics', 'No auth session; skipping remote backend enrichment');
      return;
    }
    _backendAnalytics.setToken(session.accessToken);
    final userId = session.user.id;
    FELog.d('Analytics',
        'Fetching remote backend summary & risk trend for user: $userId');

    try {
      // Parallel fetch — both calls are independent.
      final results = await Future.wait<dynamic>([
        _backendAnalytics.fetchSummary(userId),
        _backendAnalytics.fetchRiskTrend(userId),
      ]);

      final summary = results[0] as AnalyticsSummary?;
      final riskTrend = (results[1] as List).cast<RiskDayEntry>();

      state = state.copyWith(
        remoteFocusScoreAverage: summary?.focusScoreAverage,
        remoteWeeklySessions: summary?.weeklySessions,
        remoteTopApps: summary?.topDistractingApps ?? [],
        remoteRiskTrend: riskTrend,
        isRemoteLoaded: true,
      );

      FELog.i(
        'Analytics',
        'Remote backend enrichment loaded: focusAvg=${summary?.focusScoreAverage}, '
            'weeklySessions=${summary?.weeklySessions}, riskDays=${riskTrend.length}',
      );
    } catch (e) {
      FELog.w('Analytics',
          'Remote backend enrichment failed (continuing with local data): $e');
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
      return const RecoveryStats(
          rate: 0, medianRecoverySeconds: 0, sampleSize: 0);
    }
    final fast =
        recoveredSeconds.where((s) => s < _fastRecoveryThresholdSeconds).length;
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

// autoDispose: the provider is torn down when AnalyticsScreen leaves the
// widget tree, so navigating back to the tab always triggers a fresh
// loadAnalytics() call — ensuring data reflects sessions completed while
// the user was on another screen.
final analyticsProvider =
    StateNotifierProvider.autoDispose<AnalyticsViewModel, AnalyticsState>(
  (ref) => AnalyticsViewModel(
    AppDependencies.sessionDao,
    AppDependencies.eventDao,
    // MOB-3g: BackendAnalyticsService uses AppConfig.backendBaseUrl which is
    // injected at build time via --dart-define=BACKEND_URL=<url>.
    BackendAnalyticsService(),
  ),
);
