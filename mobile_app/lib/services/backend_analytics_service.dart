import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';

/// Thin client for the FastAPI analytics endpoints (MOB-3g).
///
/// All methods return `null` silently on any network / auth error so the
/// caller can fall back to local SQLite data without surfacing an error.
///
/// Endpoint map:
///   GET /api/v1/analytics/summary/{userId}   → AnalyticsSummary
///   GET /api/v1/analytics/sessions/{userId}  → List of session rows
///   GET /api/v1/analytics/risk-trend/{userId} → Daily risk trend
class BackendAnalyticsService {
  BackendAnalyticsService({String? baseUrl, String? bearerToken})
      : _baseUrl = baseUrl ?? AppConfig.backendBaseUrl,
        _bearerToken = bearerToken;

  final String _baseUrl;
  String? _bearerToken;

  /// Update the auth token (called after sign-in).
  void setToken(String token) => _bearerToken = token;

  Dio get _dio {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ));
    if (_bearerToken != null) {
      dio.options.headers['Authorization'] = 'Bearer $_bearerToken';
    }
    return dio;
  }

  // ── /api/v1/analytics/summary/{userId} ───────────────────────────────────

  /// Returns the backend summary or `null` on failure.
  /// Shape: { weekly_sessions, focus_score_average, top_distracting_apps }
  Future<AnalyticsSummary?> fetchSummary(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/v1/analytics/summary/$userId',
      );
      final data = res.data;
      if (data == null) return null;
      return AnalyticsSummary.fromJson(data);
    } catch (e) {
      debugPrint('[BackendAnalytics] fetchSummary failed: $e');
      return null;
    }
  }

  // ── /api/v1/analytics/risk-trend/{userId} ────────────────────────────────

  /// Returns a list of { date, risk_scores } objects, oldest-first.
  /// Returns empty list on failure (not null) so callers can skip rendering.
  Future<List<RiskDayEntry>> fetchRiskTrend(String userId) async {
    if (userId.isEmpty) return const [];
    try {
      final res = await _dio.get<List<dynamic>>(
        '/api/v1/analytics/risk-trend/$userId',
      );
      return (res.data ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RiskDayEntry.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[BackendAnalytics] fetchRiskTrend failed: $e');
      return const [];
    }
  }
}

// ── Value objects ─────────────────────────────────────────────────────────────

class AnalyticsSummary {
  const AnalyticsSummary({
    required this.weeklySessions,
    required this.focusScoreAverage,
    required this.topDistractingApps,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['top_distracting_apps'] as List<dynamic>? ?? [];
    // Backend returns [[label, count], ...] via Python's Counter.most_common()
    final apps = raw
        .whereType<List<dynamic>>()
        .where((e) => e.length == 2)
        .map((e) => TopApp(label: e[0].toString(), count: (e[1] as num).toInt()))
        .toList();
    return AnalyticsSummary(
      weeklySessions: (json['weekly_sessions'] as num?)?.toInt() ?? 0,
      focusScoreAverage: (json['focus_score_average'] as num?)?.toDouble() ?? 0,
      topDistractingApps: apps,
    );
  }

  final int weeklySessions;
  final double focusScoreAverage;
  final List<TopApp> topDistractingApps;
}

class TopApp {
  const TopApp({required this.label, required this.count});
  final String label;
  final int count;
}

class RiskDayEntry {
  const RiskDayEntry({required this.date, required this.riskScores});

  factory RiskDayEntry.fromJson(Map<String, dynamic> json) => RiskDayEntry(
        date: json['date'] as String? ?? '',
        riskScores: (json['risk_scores'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  final String date;
  final List<String> riskScores;
}
