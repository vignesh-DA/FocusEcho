import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/focus_session.dart';
import '../../core/models/distraction_event.dart';
import '../../core/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      todayDistractionCount:
          todayDistractionCount ?? this.todayDistractionCount,
      totalFocusMinutesToday:
          totalFocusMinutesToday ?? this.totalFocusMinutesToday,
      recoveryRate: recoveryRate ?? this.recoveryRate,
      recoveryRateTrend: recoveryRateTrend ?? this.recoveryRateTrend,
      medianRecoverySeconds:
          medianRecoverySeconds ?? this.medianRecoverySeconds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class DashboardViewModel extends StateNotifier<DashboardState> {
  DashboardViewModel(this._supabaseService, this._focusSessionDao,
      this._eventDao, this._userId)
      : super(const DashboardState()) {
    loadDashboard();
    _subscribeRealtimeDashboard();
  }

  final SupabaseService _supabaseService;
  final FocusSessionDao _focusSessionDao;
  final DistractionEventDao _eventDao;
  final String _userId;
  RealtimeChannel? _realtimeChannel;

  /// Feature 3 — same primary definition as analytics:
  /// % of distractions recovered within 30 seconds, rolling week,
  /// with a week-over-week trend.
  static const int _fastRecoveryThresholdSeconds = 30;

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Always use the live auth user — the prefs userId may be stale from
      // before the user completed OTP login.
      final authUser = Supabase.instance.client.auth.currentUser;
      final liveUserId = authUser?.id ?? _userId;

      UserProfile? profile;
      if (authUser != null) {
        try {
          profile = await _supabaseService.getUserProfile(liveUserId);
        } catch (e) {
          debugPrint('Could not fetch profile from Supabase: $e');
        }
        // Pull XP from user_xp table (same source as Streaks tab)
        try {
          final xpRow = await Supabase.instance.client
              .from('user_xp')
              .select()
              .eq('user_id', liveUserId)
              .maybeSingle();
          if (xpRow != null && profile != null) {
            profile = profile.copyWith(
              totalXp: (xpRow['total_xp'] as num?)?.toInt() ?? profile.totalXp,
              streakDays:
                  (xpRow['streak_days'] as num?)?.toInt() ?? profile.streakDays,
            );
          } else if (xpRow != null) {
            // No users-table profile yet, synthesise one from XP row
            final xp = (xpRow['total_xp'] as num?)?.toInt() ?? 0;
            final streak = (xpRow['streak_days'] as num?)?.toInt() ?? 0;
            profile = UserProfile(
              id: liveUserId,
              email: authUser.email ?? '',
              displayName: '',
              currentLevel: 1,
              levelTitle: '',
              totalXp: xp,
              streakDays: streak,
              longestStreak: streak,
              totalSessions: 0,
              totalFocusMinutes: 0,
              joinedAt: DateTime.now(),
            );
          }
        } catch (e) {
          debugPrint('Could not fetch user_xp for dashboard: $e');
        }
      }

      // Load full 7-day history so UTC-offset sessions from earlier today
      // are never missed, then narrow to local-calendar today for the stats.
      final history = await _loadSessionsFromCloud();
      final today = DateTime.now();
      final todaySessions = history
          .where((s) =>
              s.startTime.year == today.year &&
              s.startTime.month == today.month &&
              s.startTime.day == today.day)
          .toList();

      // Use all sessions for distraction count (today) — fall back to full
      // history total when today slice is empty (e.g. first load after midnight).
      final sessionsForStats = todaySessions.isNotEmpty ? todaySessions : history;
      final distractions =
          sessionsForStats.fold<int>(0, (sum, s) => sum + s.totalDistractions);
      final minutes = todaySessions.fold<int>(
        0,
        (sum, s) =>
            sum +
            ((s.endTime ?? DateTime.now()).difference(s.startTime).inMinutes),
      );

      // Feature 3 — headline Recovery Rate over rolling 7 days.
      final now = DateTime.now();
      // Pass full history so recovery rate covers a meaningful window.
      final recentEvents = await _loadEventsFromCloud(history);
      final thisWeek =
          _recoveryStatsForWindow(recentEvents, now, const Duration(days: 7));
      final lastWeek = _recoveryStatsForWindow(
        recentEvents,
        now.subtract(const Duration(days: 7)),
        const Duration(days: 7),
      );

      state = state.copyWith(
        userProfile: profile,
        todaySessions: todaySessions.isNotEmpty ? todaySessions : history,
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

  Future<List<FocusSession>> _loadSessionsFromCloud() async {
    try {
      // Use a 7-day window (same as Analytics) so UTC-offset or cross-midnight
      // sessions are never missed by a today-only filter.
      final cutoff =
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
      final rows = await Supabase.instance.client
          .from('focus_sessions')
          .select()
          .gte('start_time', cutoff)
          .order('start_time', ascending: false);
      final cloudSessions = (rows as List)
          .map((row) =>
              FocusSession.fromSqliteMap(Map<String, dynamic>.from(row as Map)))
          .toList();
      if (cloudSessions.isNotEmpty) return cloudSessions;
    } catch (e) {
      debugPrint('Web dashboard session query failed, using local cache: ' +
          e.toString());
    }
    return _focusSessionDao.getSessionHistory(50);
  }

  Future<List<DistractionEvent>> _loadEventsFromCloud(
      List<FocusSession> sessions) async {
    try {
      if (sessions.isNotEmpty) {
        final rows = await Supabase.instance.client
            .from('distraction_events')
            .select()
            .inFilter('session_id', sessions.map((s) => s.id).toList())
            .order('triggered_at');
        final cloudEvents = (rows as List)
            .map((row) => DistractionEvent.fromSqliteMap(
                Map<String, dynamic>.from(row as Map)))
            .toList();
        if (cloudEvents.isNotEmpty) return cloudEvents;
      }
    } catch (e) {
      debugPrint('Web dashboard event query failed, using local cache: ' +
          e.toString());
    }
    // Fallback: local cache per-session + recent events (mirrors Analytics)
    final events = <DistractionEvent>[];
    for (final session in sessions) {
      events.addAll(await _eventDao.getEventsForSession(session.id));
    }
    final recentLocal =
        await _eventDao.getRecentEvents(100, eventType: 'distraction');
    final seenIds = events.map((e) => e.id).toSet();
    for (final e in recentLocal) {
      if (!seenIds.contains(e.id)) events.add(e);
    }
    return events;
  }

  void _subscribeRealtimeDashboard() {
    _realtimeChannel = Supabase.instance.client
        .channel('dashboard-' + _userId)
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'focus_sessions',
            callback: (_) => loadDashboard())
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'distraction_events',
            callback: (_) => loadDashboard())
        .subscribe();
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
    final fast =
        recoveredSeconds.where((s) => s < _fastRecoveryThresholdSeconds).length;
    final sorted = List<double>.from(recoveredSeconds)..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.isEmpty
        ? 0.0
        : (sorted.length.isOdd
            ? sorted[mid]
            : (sorted[mid - 1] + sorted[mid]) / 2);
    return (rate: (fast / total) * 100, median: median);
  }

  @override
  void dispose() {
    final channel = _realtimeChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardViewModel, DashboardState>(
  (ref) => DashboardViewModel(
    AppDependencies.supabaseService,
    AppDependencies.sessionDao,
    AppDependencies.eventDao,
    // Use live auth id; prefs value may be stale before OTP login completes.
    Supabase.instance.client.auth.currentUser?.id ??
        AppDependencies.prefs.getString(AppKeys.userId) ??
        '',
  ),
);
