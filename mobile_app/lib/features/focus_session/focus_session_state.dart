import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/models/focus_session.dart';

part 'focus_session_state.freezed.dart';

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
  }) = _FocusSessionState;
}
