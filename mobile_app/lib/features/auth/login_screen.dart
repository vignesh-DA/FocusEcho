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
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _proceed() {
    if (!mounted) return;
    context.go(kIsWeb ? AppRoutes.dashboard : AppRoutes.permissionWizard);
  }

  Future<void> _submit(LoginViewModel vm, LoginState state) async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;

    if (state.isSignUp) {
      final confirm = _confirmCtrl.text;
      if (password != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
        return;
      }
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password must be at least 6 characters.')),
        );
        return;
      }
      final ok = await vm.signUp(email, password);
      if (ok && mounted) _proceed();
    } else {
      final ok = await vm.signIn(email, password);
      if (ok && mounted) _proceed();
    }
  }

  Future<void> _showForgotPassword(LoginViewModel vm) async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email and we'll send you a link to reset your password.",
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'your@email.com',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.accentBlue),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.of(ctx).pop();
              final ok = await vm.resetPassword(email);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Reset link sent to $email — check your inbox.'
                        : 'Could not send reset email. Try again.'),
                    backgroundColor:
                        ok ? AppColors.accentBlue : AppColors.accentRed,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
    emailCtrl.dispose();
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
                    state.isSignUp
                        ? 'Create an account to sync your focus\nsessions across all devices.'
                        : 'Welcome back! Sign in to continue.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 40),

                  // Email field
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
                  const SizedBox(height: 12),

                  // Password field
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.accentBlue),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  // Forgot password (sign in only)
                  if (!state.isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPassword(vm),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ),

                  // Confirm password (sign up only)
                  if (state.isSignUp) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Confirm Password',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: AppColors.accentBlue),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const SizedBox(height: 12),

                  // Submit button
                  ElevatedButton(
                    onPressed:
                        state.isLoading ? null : () => _submit(vm, state),
                    child: state.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            state.isSignUp ? 'Create Account →' : 'Sign In →'),
                  ),

                  const SizedBox(height: 16),

                  // Divider OR
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Colors.white24, thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: Colors.white24, thickness: 1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Google Sign-In button
                  OutlinedButton(
                    onPressed: state.isLoading
                        ? null
                        : () async {
                            final ok = await vm.signInWithGoogle();
                            if (ok && mounted) _proceed();
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      backgroundColor: Colors.white.withValues(alpha: 0.04),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GoogleLogo(size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Continue with Google',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Error message
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.accentRed),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Toggle sign in / sign up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        state.isSignUp
                            ? 'Already have an account? '
                            : "Don't have an account? ",
                        style:
                            const TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () => vm.toggleMode(),
                        child: Text(
                          state.isSignUp ? 'Sign In' : 'Sign Up',
                          style:
                              const TextStyle(color: AppColors.accentBlue),
                        ),
                      ),
                    ],
                  ),

                  // Skip
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

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 20});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.22;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Blue arc (bottom right to right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.35, 1.1, false, paint);

    // Green arc (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.4, false, paint);

    // Yellow arc (bottom-left to top-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.15, 1.3, false, paint);

    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.45, 1.5, false, paint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barRect = Rect.fromLTWH(
      center.dx,
      center.dy - strokeWidth / 2,
      radius,
      strokeWidth,
    );
    canvas.drawRect(barRect, barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}