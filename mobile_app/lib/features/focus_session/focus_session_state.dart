import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/models/focus_session.dart';

part 'focus_session_state.freezed.dart';

/// Summary payload captured when a session ends, rendered by the
/// session-complete view (intent + planned vs. actual duration).
@freezed
class SessionSummary with _$SessionSummary {
  const factory SessionSummary({
    required String sessionId,
    required String intent,
    required String productiveApp,
    required int actualSeconds,
    required int totalDistractions,
    required int sessionXp,
    required double focusScore,
  }) = _SessionSummary;
}

@freezed
class FocusSessionState with _$FocusSessionState {
  const factory FocusSessionState({
    @Default(false) bool isActive,
    FocusSession? session,
    @Default(0) int elapsedSeconds,
    @Default(0) int distractionCount,
    @Default(0) int sessionXp,
    @Default('SAFE') String currentRiskScore,
    @Default(false) bool showAlert,
    String? lastDistractionPackage,
    String? lastDistractionLabel,
    String? lastEventId,
    @Default([]) List<String> availableProductiveApps,
    String? selectedProductiveApp,
    // Feature 1 — Focus Intent
    @Default('') String intent,
    SessionSummary? sessionSummary,
    // Feature 2 — Escalating Intervention (relapse ladder within the session)
    @Default(1) int escalationLevel,
    // Feature 4 — cross-surface nudge text (null = nothing to show)
    String? crossSurfaceNudge,
  }) = _FocusSessionState;
}