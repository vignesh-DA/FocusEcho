import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_dependencies.dart';

class AppSelectorState {
  const AppSelectorState({
    this.selectedProductiveApps = const <String>{},
    this.selectedDistractingApps = const <String>{},
  });

  final Set<String> selectedProductiveApps;
  final Set<String> selectedDistractingApps;

  AppSelectorState copyWith({
    Set<String>? selectedProductiveApps,
    Set<String>? selectedDistractingApps,
  }) {
    return AppSelectorState(
      selectedProductiveApps: selectedProductiveApps ?? this.selectedProductiveApps,
      selectedDistractingApps: selectedDistractingApps ?? this.selectedDistractingApps,
    );
  }
}

class AppSelectorViewModel extends StateNotifier<AppSelectorState> {
  AppSelectorViewModel(this._prefs) : super(const AppSelectorState());

  final SharedPreferences _prefs;

  static const productiveApps = <String, String>{
    'com.google.android.youtube': 'YouTube',
    'notion.id': 'Notion',
    'com.microsoft.vscode': 'VS Code',
    'com.google.android.apps.docs': 'Google Docs',
    'com.github.android': 'GitHub',
    'org.coursera.android': 'Coursera',
    'org.khanacademy.android': 'Khan Academy',
    'com.duolingo': 'Duolingo',
  };

  static const distractingApps = <String, String>{
    'com.instagram.android': 'Instagram',
    'com.zhiliaoapp.musically': 'TikTok',
    'com.twitter.android': 'Twitter/X',
    'com.facebook.katana': 'Facebook',
    'com.snapchat.android': 'Snapchat',
    'com.reddit.frontpage': 'Reddit',
    'com.whatsapp': 'WhatsApp',
    'com.netflix.mediaclient': 'Netflix',
  };

  void toggleProductiveApp(String packageName) {
    final selected = {...state.selectedProductiveApps};
    selected.contains(packageName) ? selected.remove(packageName) : selected.add(packageName);
    state = state.copyWith(selectedProductiveApps: selected);
  }

  void toggleDistractingApp(String packageName) {
    final selected = {...state.selectedDistractingApps};
    selected.contains(packageName) ? selected.remove(packageName) : selected.add(packageName);
    state = state.copyWith(selectedDistractingApps: selected);
  }

  Future<void> saveSelection() async {
    await _prefs.setString(AppKeys.productiveApps, jsonEncode(state.selectedProductiveApps.toList()));
    await _prefs.setString(AppKeys.distractingApps, jsonEncode(state.selectedDistractingApps.toList()));
  }

  bool get isValid => state.selectedProductiveApps.isNotEmpty && state.selectedDistractingApps.isNotEmpty;
}

final appSelectorProvider = StateNotifierProvider<AppSelectorViewModel, AppSelectorState>(
  (ref) => AppSelectorViewModel(AppDependencies.prefs),
);
