import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_dependencies.dart';
import 'permission_state.dart';

/// Permission wizard view-model.
///
/// Decision 2026-10-03: Accessibility service removed — single detection path
/// via UsageStats only.  Wizard now checks two permissions:
///   1. Usage Access (PACKAGE_USAGE_STATS)
///   2. Battery Optimization exemption
///
/// [hasAccessibility] is kept in state for forward compatibility but is always
/// reported as `true` so it never blocks the wizard flow.
class PermissionWizardViewModel extends StateNotifier<PermissionWizardState> {
  PermissionWizardViewModel(this._prefs)
      : _permissionChannel = const MethodChannel(AppChannels.permissions),
        _batteryChannel = const MethodChannel(AppChannels.battery),
        super(const PermissionWizardState()) {
    unawaited(checkAllPermissions());
  }

  final SharedPreferences _prefs;
  final MethodChannel _permissionChannel;
  final MethodChannel _batteryChannel;

  Future<void> checkAllPermissions() async {
    if (kIsWeb) {
      await _prefs.setBool('has_usage_access', true);
      await _prefs.setBool('has_battery_optimization', true);
      state = state.copyWith(
        hasUsageAccess: true,
        hasAccessibility: true, // not used — kept for compat
        hasBatteryOptimization: true,
        isChecking: false,
      );
      return;
    }

    state = state.copyWith(isChecking: true);
    bool hasUsage = false;
    bool hasBattery = false;

    try {
      hasUsage = await _permissionChannel.invokeMethod<bool>('checkUsageAccess') ?? false;
      hasBattery =
          await _permissionChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } on MissingPluginException {
      hasUsage = true;
      hasBattery = true;
    } on PlatformException {
      hasUsage = false;
      hasBattery = false;
    }

    await _prefs.setBool('has_usage_access', hasUsage);
    await _prefs.setBool('has_battery_optimization', hasBattery);
    // Accessibility is no longer required — always report granted so the
    // router redirect never blocks on it.
    await _prefs.setBool('has_accessibility', true);
    state = state.copyWith(
      hasUsageAccess: hasUsage,
      hasAccessibility: true,
      hasBatteryOptimization: hasBattery,
      isChecking: false,
    );
  }

  Future<void> openUsageAccessSettings() async {
    if (kIsWeb) return;
    await _permissionChannel.invokeMethod<void>('openUsageSettings');
  }

  Future<void> requestBatteryOptimization() async {
    if (kIsWeb) return;
    final flow =
        await _batteryChannel.invokeMethod<Map<dynamic, dynamic>>('runBatteryOptimizationFlow') ??
        const <dynamic, dynamic>{};
    await _prefs.setString('battery_optimization_flow', jsonEncode(flow));
    await checkAllPermissions();
  }

  Future<void> openManufacturerBatterySettings() async {
    if (kIsWeb) return;
    await _batteryChannel.invokeMethod<void>('openManufacturerBatterySettings');
  }

  Future<void> nextPage(PageController controller, BuildContext context) async {
    final canProceed = switch (state.currentPage) {
      0 => state.hasUsageAccess,
      1 => state.hasBatteryOptimization,
      _ => isAllGranted,
    };

    if (!canProceed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant this permission to continue.')),
      );
      return;
    }

    if (state.currentPage < 2) {
      final next = state.currentPage + 1;
      state = state.copyWith(currentPage: next);
      await controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// All required permissions granted (usage + battery).
  /// Accessibility is intentionally excluded — removed from product scope.
  bool get isAllGranted => state.hasUsageAccess && state.hasBatteryOptimization;
}

final permissionWizardProvider =
    StateNotifierProvider<PermissionWizardViewModel, PermissionWizardState>(
  (ref) => PermissionWizardViewModel(AppDependencies.prefs),
);
