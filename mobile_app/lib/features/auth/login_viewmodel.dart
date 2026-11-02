import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/app_dependencies.dart';
import '../../../core/utils/fe_logger.dart';

class LoginState {
  const LoginState({
    this.isLoading = false,
    this.errorMessage,
    this.isSignUp = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final bool isSignUp;

  LoginState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isSignUp,
  }) =>
      LoginState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
        isSignUp: isSignUp ?? this.isSignUp,
      );
}

class LoginViewModel extends StateNotifier<LoginState> {
  LoginViewModel(this._prefs) : super(const LoginState());

  final SharedPreferences _prefs;
  SupabaseClient? _client;

  SupabaseClient? get _availableClient {
    try {
      return _client ??= Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void toggleMode() {
    state = state.copyWith(isSignUp: !state.isSignUp, errorMessage: null);
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    FELog.i('Auth', 'Signing in: $email');
    try {
      final client = _availableClient;
      if (client == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sign-in is unavailable while offline.',
        );
        return false;
      }
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final userId = response.user?.id;
      FELog.i('Auth', 'Signed in successfully. User ID: $userId');
      if (userId != null) {
        await _prefs.setString(AppKeys.userId, userId);
      }
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e, st) {
      FELog.w('Auth', 'AuthException during signIn: ${e.message}');
      FELog.e('Auth', 'AuthException details', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e.message),
      );
      return false;
    } catch (e, st) {
      FELog.e('Auth', 'Unexpected error during signIn', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Try again.',
      );
      return false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    FELog.i('Auth', 'Signing up: $email');
    try {
      final client = _availableClient;
      if (client == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sign-up is unavailable while offline.',
        );
        return false;
      }
      final response = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kIsWeb ? Uri.base.origin : _nativeRedirectUrl,
      );
      final userId = response.user?.id;
      FELog.i('Auth', 'Signed up successfully. User ID: $userId');
      if (userId != null) {
        await _prefs.setString(AppKeys.userId, userId);
      }
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e, st) {
      FELog.w('Auth', 'AuthException during signUp: ${e.message}');
      FELog.e('Auth', 'AuthException details', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e.message),
      );
      return false;
    } catch (e, st) {
      FELog.e('Auth', 'Unexpected error during signUp', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Try again.',
      );
      return false;
    }
  }

  // The custom URL scheme registered in AndroidManifest.xml and Info.plist.
  // Supabase will redirect the browser back to this URI after the user
  // approves Google access; app_links picks it up and passes it to
  // Supabase.getSessionFromUrl() so the session is established natively.
  static const _nativeRedirectUrl = 'com.focusecho.ai://login-callback';

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    FELog.i('Auth', 'Starting Google OAuth sign-in');
    try {
      final client = _availableClient;
      if (client == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sign-in is unavailable while offline.',
        );
        return false;
      }
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        // Web: Supabase redirects back to the same origin (no custom scheme).
        // Native (Android / iOS): the OS intercepts the custom scheme URI and
        // hands the URL to app_links → getSessionFromUrl() in main.dart.
        redirectTo: kIsWeb ? Uri.base.origin : _nativeRedirectUrl,
      );
      // On native the browser opens and the redirect is handled asynchronously
      // by the app_links listener in main.dart. We clear loading here so the
      // button is re-enabled if the user cancels the browser.
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e, st) {
      FELog.w('Auth', 'AuthException during Google sign-in: ${e.message}');
      FELog.e('Auth', 'AuthException details', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e.message),
      );
      return false;
    } catch (e, st) {
      FELog.e('Auth', 'Unexpected error during Google sign-in', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Network error. Try again.',
      );
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    FELog.i('Auth', 'Sending password reset to $email');
    try {
      final client = _availableClient;
      if (client == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unavailable while offline.',
        );
        return false;
      }
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb ? Uri.base.origin : _nativeRedirectUrl,
      );
      FELog.i('Auth', 'Password reset email sent to $email');
      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e, st) {
      FELog.w('Auth', 'AuthException during resetPassword: ${e.message}');
      FELog.e('Auth', 'AuthException details', e, st);
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyError(e.message),
      );
      return false;
    } catch (e, st) {
      FELog.e('Auth', 'Unexpected error during resetPassword', e, st);
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

  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return 'An account with this email already exists. Sign in instead.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('unable to validate email')) {
      return 'Please enter a valid email address.';
    }
    return raw;
  }
}

final loginViewModelProvider =
    StateNotifierProvider<LoginViewModel, LoginState>(
  (ref) => LoginViewModel(AppDependencies.prefs),
);
