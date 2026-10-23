import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_dependencies.dart';

class LoginState {
  const LoginState({this.isLoading = false, this.errorMessage});

  final bool isLoading;
  final String? errorMessage;

  LoginState copyWith({bool? isLoading, String? errorMessage}) => LoginState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class LoginViewModel extends StateNotifier<LoginState> {
  LoginViewModel(this._prefs) : super(const LoginState());

  final SharedPreferences _prefs;
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> sendOtp(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser?.isAnonymous == true) {
        // Upgrade the anonymous identity in place so its cloud rows remain
        // owned by the same auth.uid() after email confirmation.
        await _client.auth.updateUser(UserAttributes(email: email));
      } else {
        await _client.auth.signInWithOtp(
          email: email,
          shouldCreateUser: true,
        );
      }
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Try again.',
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String token) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Try again.',
      );
      return false;
    }
  }

  Future<void> skipLogin() => _prefs.setBool(AppKeys.hasSkippedLogin, true);
}

final loginViewModelProvider =
    StateNotifierProvider<LoginViewModel, LoginState>(
  (ref) => LoginViewModel(AppDependencies.prefs),
);
