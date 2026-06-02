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
      await _prefs.setBool('has_accessibility', true);
      await _prefs.setBool('has_battery_optimization', true);
      state = state.copyWith(
        hasUsageAccess: true,
        hasAccessibility: true,
        hasBatteryOptimization: true,
        isChecking: false,
      );
      return;
    }

    state = state.copyWith(isChecking: true);
    bool hasUsage = false;
    bool hasAccessibility = false;
    bool hasBattery = false;

    try {
      hasUsage = await _permissionChannel.invokeMethod<bool>('checkUsageAccess') ?? false;
      hasAccessibility = await _permissionChannel.invokeMethod<bool>('checkAccessibility') ?? false;
      hasBattery = await _permissionChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } on MissingPluginException {
      hasUsage = true;
      hasAccessibility = true;
      hasBattery = true;
    } on PlatformException {
      hasUsage = false;
      hasAccessibility = false;
      hasBattery = false;
    }

    await _prefs.setBool('has_usage_access', hasUsage);
    await _prefs.setBool('has_accessibility', hasAccessibility);
    await _prefs.setBool('has_battery_optimization', hasBattery);
    state = state.copyWith(
      hasUsageAccess: hasUsage,
      hasAccessibility: hasAccessibility,
      hasBatteryOptimization: hasBattery,
      isChecking: false,
    );
  }

  Future<void> openUsageAccessSettings() async {
    if (kIsWeb) return;
    await _permissionChannel.invokeMethod<void>('openUsageSettings');
  }

  Future<void> openAccessibilitySettings() async {
    if (kIsWeb) return;
    await _permissionChannel.invokeMethod<void>('openAccessibilitySettings');
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
      1 => state.hasAccessibility,
      2 => state.hasBatteryOptimization,
      _ => isAllGranted,
    };

    if (!canProceed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant this permission to continue.')),
      );
      return;
    }

    if (state.currentPage < 3) {
      final next = state.currentPage + 1;
      state = state.copyWith(currentPage: next);
      await controller.animateToPage(next, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  bool get isAllGranted => state.hasUsageAccess && state.hasAccessibility && state.hasBatteryOptimization;
}

final permissionWizardProvider = StateNotifierProvider<PermissionWizardViewModel, PermissionWizardState>(
  (ref) => PermissionWizardViewModel(AppDependencies.prefs),
);
