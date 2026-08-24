import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_dependencies.dart';
import '../../../services/supabase_service.dart';

class LoginViewModel extends StateNotifier<bool> {
  LoginViewModel(this._supabaseService, this._prefs) : super(false);

  final SupabaseService _supabaseService;
  final SharedPreferences _prefs;

  Future<void> signInWithGoogle() async {
    state = true;
    try {
      await _supabaseService.signInWithGoogle();
      // The auth listener in main.dart will handle the migration and state
    } catch (e) {
      // Handle error visually if necessary
    } finally {
      state = false;
    }
  }

  Future<void> skipLogin() async {
    await _prefs.setBool(AppKeys.hasSkippedLogin, true);
  }
}

final loginViewModelProvider = StateNotifierProvider<LoginViewModel, bool>((ref) {
  return LoginViewModel(AppDependencies.supabaseService, AppDependencies.prefs);
});
