import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_dependencies.dart';
import '../../../core/utils/fe_logger.dart';

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
    FELog.i('Auth', 'Sending OTP to $email');
    try {
      final currentUser = _client.auth.currentUser;
      if (currentUser?.isAnonymous == true) {
        FELog.d('Auth', 'Upgrading anonymous user ${currentUser?.id} with email $email');
        await _client.auth.updateUser(UserAttributes(email: email));
      } else {
        await _client.auth.signInWithOtp(
          email: email,
          shouldCreateUser: true,
        );
      }
      FELog.i('Auth', 'OTP sent successfully to $email');
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e, st) {
      FELog.w('Auth', 'AuthException during sendOtp: ${e.message}');
      FELog.e('Auth', 'AuthException details', e, st);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e, st) {
      FELog.e('Auth', 'Unexpected error during sendOtp', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Try again.',
      );
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String token) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    FELog.i('Auth', 'Verifying OTP for $email (token length: ${token.length})');
    try {
      final resp = await _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
      final userId = resp.user?.id ?? _client.auth.currentUser?.id;
      FELog.i('Auth', 'OTP verified successfully! User ID: $userId');
      if (userId != null) {
        await _prefs.setString(AppKeys.userId, userId);
      }
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e, st) {
      FELog.w('Auth', 'AuthException during verifyOtp: ${e.message}');
      FELog.e('Auth', 'AuthException details', e, st);
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e, st) {
      FELog.e('Auth', 'Unexpected error during verifyOtp', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Try again.',
      );
      return false;
    }
  }

  Future<void> skipLogin() {
    FELog.i('Auth', 'User skipped login, continuing as guest');
    return _prefs.setBool(AppKeys.hasSkippedLogin, true);
  }
}

final loginViewModelProvider =
    StateNotifierProvider<LoginViewModel, LoginState>(
  (ref) => LoginViewModel(AppDependencies.prefs),
);
