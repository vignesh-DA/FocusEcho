import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';

class IntentionRefineResult {
  const IntentionRefineResult({
    required this.isSufficientlyClear,
    required this.refinedIntention,
    required this.clarityScore,
    required this.coachFeedback,
    required this.isFallback,
  });

  final bool isSufficientlyClear;
  final String refinedIntention;
  final int clarityScore;
  final String coachFeedback;
  final bool isFallback;

  factory IntentionRefineResult.fromJson(Map<String, dynamic> json) {
    return IntentionRefineResult(
      isSufficientlyClear: json['is_sufficiently_clear'] as bool? ?? true,
      refinedIntention: (json['refined_intention'] as String?) ?? '',
      clarityScore: (json['clarity_score'] as num?)?.toInt() ?? 60,
      coachFeedback: (json['coach_feedback'] as String?) ?? '',
      isFallback: json['is_fallback'] as bool? ?? false,
    );
  }
}

class SessionDebriefResult {
  const SessionDebriefResult({
    required this.sessionId,
    required this.headline,
    required this.body,
    required this.actionableTip,
    required this.distractionMinuteOffsets,
    required this.totalSessionsAnalyzed,
    required this.isFallback,
    required this.isCached,
  });

  final String sessionId;
  final String headline;
  final String body;
  final String actionableTip;
  final List<double> distractionMinuteOffsets;
  final int totalSessionsAnalyzed;
  final bool isFallback;
  final bool isCached;

  factory SessionDebriefResult.fromJson(Map<String, dynamic> json) {
    final rawOffsets = json['distraction_minute_offsets'] as List? ?? [];
    final offsets = rawOffsets.map((e) => (e as num).toDouble()).toList();

    return SessionDebriefResult(
      sessionId: (json['session_id'] as String?) ?? '',
      headline: (json['headline'] as String?) ?? 'Session Complete',
      body: (json['body'] as String?) ?? '',
      actionableTip: (json['actionable_tip'] as String?) ?? '',
      distractionMinuteOffsets: offsets,
      totalSessionsAnalyzed: (json['total_sessions_analyzed'] as num?)?.toInt() ?? 1,
      isFallback: json['is_fallback'] as bool? ?? false,
      isCached: json['is_cached'] as bool? ?? false,
    );
  }
}

class AiCoachService {
  AiCoachService({
    String? baseUrl,
    SupabaseClient? supabaseClient,
  })  : _baseUrl = baseUrl ?? AppConfig.backendBaseUrl,
        _supabase = supabaseClient ?? Supabase.instance.client;

  final String _baseUrl;
  final SupabaseClient _supabase;

  Dio get _dio {
    final token = _supabase.auth.currentSession?.accessToken;
    final options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 5),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
    return Dio(options);
  }

  /// Check whether user has opted into EchoCoach
  Future<bool> getOptInStatus() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/coach/opt-in');
      return (res.data?['is_opted_in'] as bool?) ?? false;
    } catch (e) {
      debugPrint('[AiCoachService] getOptInStatus error: $e');
      return false;
    }
  }

  /// Update opt-in consent
  Future<bool> setOptInStatus(bool optIn) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/coach/opt-in',
        data: {'opt_in': optIn},
      );
      return (res.data?['is_opted_in'] as bool?) ?? optIn;
    } catch (e) {
      debugPrint('[AiCoachService] setOptInStatus error: $e');
      return optIn;
    }
  }

  /// Pre-session intention refiner (tap-to-refine with debounce)
  Future<IntentionRefineResult> refineIntention(String rawIntention) async {
    final trimmed = rawIntention.trim();
    if (trimmed.isEmpty) {
      return const IntentionRefineResult(
        isSufficientlyClear: false,
        refinedIntention: 'Complete one focused task',
        clarityScore: 20,
        coachFeedback: 'Intention cannot be empty. Define one concrete deliverable.',
        isFallback: true,
      );
    }

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/coach/refine-intention',
        data: {'raw_intention': trimmed},
      );
      if (res.data != null) {
        return IntentionRefineResult.fromJson(res.data!);
      }
    } catch (e) {
      debugPrint('[AiCoachService] refineIntention remote call failed: $e');
    }

    // Local deterministic fallback
    return _localFallbackRefine(trimmed);
  }

  /// Post-session debrief generator.
  /// Carries ONLY session_id. All stats and minute offsets computed on server.
  Future<SessionDebriefResult?> fetchSessionDebrief(String sessionId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/coach/session-debrief',
        data: {'session_id': sessionId},
      );
      if (res.data != null) {
        return SessionDebriefResult.fromJson(res.data!);
      }
    } catch (e) {
      debugPrint('[AiCoachService] fetchSessionDebrief error: $e');
    }
    return null;
  }

  /// Submit user feedback (-1 = unhelpful, 1 = helpful)
  Future<bool> submitFeedback(String insightId, int feedback) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/coach/feedback',
        data: {
          'insight_id': insightId,
          'feedback': feedback,
        },
      );
      return (res.data?['ok'] as bool?) ?? false;
    } catch (e) {
      debugPrint('[AiCoachService] submitFeedback error: $e');
      return false;
    }
  }

  IntentionRefineResult _localFallbackRefine(String intention) {
    final words = intention.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    if (words.length < 3) {
      return IntentionRefineResult(
        isSufficientlyClear: false,
        refinedIntention: 'Focus on: ${intention[0].toUpperCase()}${intention.substring(1)} (complete 1 deliverable)',
        clarityScore: 40,
        coachFeedback: 'Consider adding a measurable output so you know when the session is complete.',
        isFallback: true,
      );
    }

    return IntentionRefineResult(
      isSufficientlyClear: true,
      refinedIntention: intention,
      clarityScore: 80,
      coachFeedback: 'Clear intention. Protect this block from distractions.',
      isFallback: true,
    );
  }
}
