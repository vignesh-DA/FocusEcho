import 'package:freezed_annotation/freezed_annotation.dart';

part 'permission_state.freezed.dart';

@freezed
class PermissionWizardState with _$PermissionWizardState {
  const factory PermissionWizardState({
    @Default(0) int currentPage,
    @Default(false) bool hasUsageAccess,
    @Default(false) bool hasAccessibility,
    @Default(false) bool hasBatteryOptimization,
    @Default(false) bool isChecking,
  }) = _PermissionWizardState;
}
