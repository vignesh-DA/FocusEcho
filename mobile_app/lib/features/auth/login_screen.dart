import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'login_viewmodel.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        if (mounted) {
          _proceed(context);
        }
      }
    });
  }

  Future<void> _proceed(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final usage = prefs.getBool('has_usage_access') ?? false;
    final accessibility = prefs.getBool('has_accessibility') ?? false;
    final battery = prefs.getBool('has_battery_optimization') ?? false;

    if (!context.mounted) return;

    if (kIsWeb) {
      context.go(AppRoutes.dashboard);
      return;
    }

    if (!(usage && accessibility && battery)) {
      context.go(AppRoutes.permissionWizard);
      return;
    }

    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(loginViewModelProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, Color(0xFF020617)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_person_rounded, size: 80, color: AppColors.accentBlue),
                  const SizedBox(height: 32),
                  Text(
                    'Sync Your Progress',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displayLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to save your focus streaks, earn XP, and sync across all your devices.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 48),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => ref.read(loginViewModelProvider.notifier).signInWithGoogle(),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 32, color: Colors.black),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      await ref.read(loginViewModelProvider.notifier).skipLogin();
                      if (context.mounted) {
                        _proceed(context);
                      }
                    },
                    child: Text(
                      'Continue as Guest',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
