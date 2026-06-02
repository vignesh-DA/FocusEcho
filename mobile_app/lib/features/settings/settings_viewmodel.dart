import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_dependencies.dart';
import '../../local_db/database_helper.dart';

class SettingsState {
  static const Object _noChange = Object();

  const SettingsState({
    this.strictness = 'Normal',
    this.recoveryDuration = 10,
    this.cloudSyncEnabled = true,
    this.analyticsEnabled = true,
    this.localOnlyMode = false,
    this.nudgesEnabled = true,
    this.streakRemindersEnabled = true,
    this.userEmail,
    this.isAuthenticating = false,
    this.isDeletingData = false,
    this.appLimits = const {},
  });

  final String strictness;
  final int recoveryDuration;
  final bool cloudSyncEnabled;
  final bool analyticsEnabled;
  final bool localOnlyMode;
  final bool nudgesEnabled;
  final bool streakRemindersEnabled;
  final String? userEmail;
  final bool isAuthenticating;
  final bool isDeletingData;
  final Map<String, int> appLimits;

  SettingsState copyWith({
    String? strictness,
    int? recoveryDuration,
    bool? cloudSyncEnabled,
    bool? analyticsEnabled,
    bool? localOnlyMode,
    bool? nudgesEnabled,
    bool? streakRemindersEnabled,
    Object? userEmail = _noChange,
    bool? isAuthenticating,
    bool? isDeletingData,
    Map<String, int>? appLimits,
  }) {
    return SettingsState(
      strictness: strictness ?? this.strictness,
      recoveryDuration: recoveryDuration ?? this.recoveryDuration,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      localOnlyMode: localOnlyMode ?? this.localOnlyMode,
      nudgesEnabled: nudgesEnabled ?? this.nudgesEnabled,
      streakRemindersEnabled: streakRemindersEnabled ?? this.streakRemindersEnabled,
      userEmail: userEmail == _noChange ? this.userEmail : userEmail as String?,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isDeletingData: isDeletingData ?? this.isDeletingData,
      appLimits: appLimits ?? this.appLimits,
    );
  }
}

class SettingsViewModel extends StateNotifier<SettingsState> {
  SettingsViewModel(this._prefs) : super(const SettingsState()) {
    final currentUser = AppDependencies.supabaseService.currentUser;
    state = state.copyWith(
      cloudSyncEnabled: _prefs.getBool(AppKeys.syncEnabled) ?? true,
      analyticsEnabled: _prefs.getBool(AppKeys.analyticsEnabled) ?? true,
      localOnlyMode: _prefs.getBool(AppKeys.localOnlyMode) ?? false,
      nudgesEnabled: _prefs.getBool('nudges_enabled') ?? true,
      streakRemindersEnabled: _prefs.getBool('streak_reminders_enabled') ?? true,
      recoveryDuration: _prefs.getInt('recovery_duration') ?? 10,
      strictness: _prefs.getString('strictness') ?? 'Normal',
      userEmail: currentUser?.email,
      appLimits: _loadAppLimits(),
    );
    if (currentUser != null) {
      // userId is saved by the auth state listener in main.dart
      // This handles the app-restart case where session is already active
      _prefs.setString(AppKeys.userId, currentUser.id);
    }
  }

  final SharedPreferences _prefs;

  Future<void> updateStrictness(String value) async {
    state = state.copyWith(strictness: value);
    await _prefs.setString('strictness', value);
  }

  Future<void> updateRecoveryDuration(int value) async {
    state = state.copyWith(recoveryDuration: value);
    await _prefs.setInt('recovery_duration', value);
  }

  Future<void> updateCloudSync(bool value) async {
    if (state.localOnlyMode) return;
    state = state.copyWith(cloudSyncEnabled: value);
    await _prefs.setBool(AppKeys.syncEnabled, value);
  }

  Future<void> updateAnalytics(bool value) async {
    if (state.localOnlyMode) return;
    state = state.copyWith(analyticsEnabled: value);
    await _prefs.setBool(AppKeys.analyticsEnabled, value);
  }

  Future<void> updateLocalOnly(bool value) async {
    final next = state.copyWith(
      localOnlyMode: value,
      cloudSyncEnabled: value ? false : state.cloudSyncEnabled,
      analyticsEnabled: value ? false : state.analyticsEnabled,
    );
    state = next;
    await _prefs.setBool(AppKeys.localOnlyMode, value);
    await _prefs.setBool(AppKeys.syncEnabled, next.cloudSyncEnabled);
    await _prefs.setBool(AppKeys.analyticsEnabled, next.analyticsEnabled);
  }

  Future<void> updateNudges(bool value) async {
    state = state.copyWith(nudgesEnabled: value);
    await _prefs.setBool('nudges_enabled', value);
  }

  Future<void> updateStreakReminders(bool value) async {
    state = state.copyWith(streakRemindersEnabled: value);
    await _prefs.setBool('streak_reminders_enabled', value);
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isAuthenticating: false);
    // OAuth opens a browser — the actual sign-in completes asynchronously
    // via a deep-link redirect. The auth state listener in main.dart will
    // save the userId and migrate guest data when signedIn fires.
    final started = await AppDependencies.supabaseService.signInWithGoogle();
    state = state.copyWith(isAuthenticating: false);
    return started;
  }

  Future<void> signOut() async {
    state = state.copyWith(isAuthenticating: true);
    await AppDependencies.supabaseService.signOut();
    final deviceId = _prefs.getString(AppKeys.deviceId);
    if (deviceId != null && deviceId.isNotEmpty) {
      await _prefs.setString(AppKeys.userId, deviceId);
    } else {
      await _prefs.remove(AppKeys.userId);
    }
    state = state.copyWith(isAuthenticating: false, userEmail: null);
  }

  Future<void> updateAppLimit(String packageName, int seconds) async {
    final newLimits = Map<String, int>.from(state.appLimits);
    if (seconds <= 0) {
      newLimits.remove(packageName);
    } else {
      newLimits[packageName] = seconds;
    }
    state = state.copyWith(appLimits: newLimits);
    await _prefs.setString(AppKeys.appTimeLimitsSeconds, jsonEncode(newLimits));
  }

  Map<String, int> _loadAppLimits() {
    final raw = _prefs.getString(AppKeys.appTimeLimitsSeconds) ?? '{}';
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return const {};
    }
  }

  Future<String> deleteMyData() async {
    state = state.copyWith(isDeletingData: true);
    final currentUser = AppDependencies.supabaseService.currentUser;
    try {
      if (currentUser != null) {
        await AppDependencies.supabaseService.deleteCurrentUserData();
      }
      await DatabaseHelper.instance.clearAllUserData();
      await _clearPrivacyDataFromPrefs();
      state = const SettingsState();
      return currentUser == null
          ? 'Local data deleted from this device.'
          : 'Cloud and local data deleted successfully.';
    } on PostgrestException catch (e) {
      throw StateError('Cloud deletion failed: ${e.message}');
    } on AuthException catch (e) {
      throw StateError('Authentication error: ${e.message}');
    } finally {
      if (state.isDeletingData) {
        state = state.copyWith(isDeletingData: false);
      }
    }
  }

  Future<void> _clearPrivacyDataFromPrefs() async {
    await _prefs.remove(AppKeys.userId);
    await _prefs.remove(AppKeys.productiveApps);
    await _prefs.remove(AppKeys.distractingApps);
    await _prefs.remove(AppKeys.xpTotal);
    await _prefs.remove(AppKeys.streakDays);
    await _prefs.setBool(AppKeys.sessionActive, false);
    await _prefs.setBool(AppKeys.consentGiven, false);
    final deviceId = _prefs.getString(AppKeys.deviceId);
    if (deviceId != null && deviceId.isNotEmpty) {
      await _prefs.setString(AppKeys.userId, deviceId);
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsViewModel, SettingsState>(
  (ref) => SettingsViewModel(AppDependencies.prefs),
);
