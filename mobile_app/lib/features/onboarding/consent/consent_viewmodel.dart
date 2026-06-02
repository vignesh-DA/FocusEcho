import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_dependencies.dart';

class ConsentState {
  const ConsentState({
    this.analyticsEnabled = true,
    this.cloudSyncEnabled = true,
    this.localOnlyMode = false,
    this.isSaving = false,
  });

  final bool analyticsEnabled;
  final bool cloudSyncEnabled;
  final bool localOnlyMode;
  final bool isSaving;

  ConsentState copyWith({
    bool? analyticsEnabled,
    bool? cloudSyncEnabled,
    bool? localOnlyMode,
    bool? isSaving,
  }) {
    return ConsentState(
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      localOnlyMode: localOnlyMode ?? this.localOnlyMode,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

class ConsentViewModel extends StateNotifier<ConsentState> {
  ConsentViewModel(this._prefs) : super(const ConsentState());

  final SharedPreferences _prefs;

  void toggleAnalytics(bool value) => state = state.copyWith(analyticsEnabled: value);

  void toggleCloudSync(bool value) {
    if (state.localOnlyMode) return;
    state = state.copyWith(cloudSyncEnabled: value);
  }

  void toggleLocalOnly(bool value) {
    state = state.copyWith(localOnlyMode: value, cloudSyncEnabled: value ? false : state.cloudSyncEnabled);
  }

  Future<void> saveConsent() async {
    state = state.copyWith(isSaving: true);
    await _prefs.setBool(AppKeys.analyticsEnabled, state.analyticsEnabled);
    await _prefs.setBool(AppKeys.syncEnabled, state.cloudSyncEnabled);
    await _prefs.setBool(AppKeys.localOnlyMode, state.localOnlyMode);
    await _prefs.setBool(AppKeys.consentGiven, true);
    state = state.copyWith(isSaving: false);
  }
}

final consentProvider = StateNotifierProvider<ConsentViewModel, ConsentState>(
  (ref) => ConsentViewModel(AppDependencies.prefs),
);
