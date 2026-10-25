import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'login_viewmodel.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _proceed() {
    if (!mounted) return;
    context.go(kIsWeb ? AppRoutes.dashboard : AppRoutes.permissionWizard);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginViewModelProvider);
    final vm = ref.read(loginViewModelProvider.notifier);

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
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.graphic_eq_rounded,
                      size: 72, color: AppColors.accentBlue),
                  const SizedBox(height: 24),
                  Text(
                    'Focus Echo AI',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.displayLarge
                        .copyWith(color: AppColors.accentBlue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _otpSent
                        ? 'Enter the 8-digit code sent to\n${_emailCtrl.text}'
                        : 'Create an account to sync your focus\nsessions across all devices.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 40),
                  if (!_otpSent) ...[
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'your@email.com',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.email_outlined,
                            color: AppColors.accentBlue),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              final email = _emailCtrl.text.trim();
                              if (email.isEmpty) return;
                              final ok = await vm.sendOtp(email);
                              if (ok && mounted) {
                                setState(() => _otpSent = true);
                              }
                            },
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Send Code →'),
                    ),
                  ] else ...[
                    TextField(
                      controller: _otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '00000000',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              final ok = await vm.verifyOtp(
                                _emailCtrl.text.trim(),
                                _otpCtrl.text.trim(),
                              );
                              if (ok) _proceed();
                            },
                      child: state.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verify & Sign In'),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _otpSent = false;
                        _otpCtrl.clear();
                      }),
                      child: const Text('← Change Email'),
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.accentRed),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () async {
                      await vm.skipLogin();
                      _proceed();
                    },
                    child: const Text('Continue without account'),
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