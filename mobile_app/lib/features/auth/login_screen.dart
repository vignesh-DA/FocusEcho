import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'login_viewmodel.dart';

// ---------------------------------------------------------------------------
// Login Screen — Premium Redesign
// ---------------------------------------------------------------------------
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Focus nodes for animated field borders
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  // Animation controllers
  late final AnimationController _orbController;
  late final AnimationController _fadeController;
  late final AnimationController _tabController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideIn;

  // Tracks which tab was previously shown so we can animate the switch
  bool _prevIsSignUp = false;

  @override
  void initState() {
    super.initState();

    // Slow-rotating orbs behind the card
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // Page fade-in on first show
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideIn = Tween<double>(begin: 36, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
    _fadeController.forward();

    // Tab transition controller (sign in ↔ sign up)
    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    // Rebuild on focus change so borders light up
    for (final n in [_emailFocus, _passwordFocus, _confirmFocus]) {
      n.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    _orbController.dispose();
    _fadeController.dispose();
    _tabController.dispose();
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
        _showSnack('Passwords do not match.', isError: true);
        return;
      }
      if (password.length < 6) {
        _showSnack('Password must be at least 6 characters.', isError: true);
        return;
      }
      final ok = await vm.signUp(email, password);
      if (ok && mounted) _proceed();
    } else {
      final ok = await vm.signIn(email, password);
      if (ok && mounted) _proceed();
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? AppColors.accentRed.withValues(alpha: 0.92)
            : AppColors.accentBlue.withValues(alpha: 0.92),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );
  }

  Future<void> _showForgotPassword(LoginViewModel vm) async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    await showDialog<void>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        emailCtrl: emailCtrl,
        onSend: (email) async {
          Navigator.of(ctx).pop();
          final ok = await vm.resetPassword(email);
          if (mounted) {
            _showSnack(
              ok
                  ? 'Reset link sent to $email — check your inbox.'
                  : 'Could not send reset email. Try again.',
              isError: !ok,
            );
          }
        },
      ),
    );
    emailCtrl.dispose();
  }

  void _toggleMode(LoginViewModel vm) {
    setState(() => _prevIsSignUp = !_prevIsSignUp);
    vm.toggleMode();
    _tabController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginViewModelProvider);
    final vm = ref.read(loginViewModelProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          // -- Animated gradient background --
          const _AnimatedBackground(),

          // -- Animated orbs --
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, __) => _OrbLayer(progress: _orbController.value),
          ),

          // -- Main content --
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: AnimatedBuilder(
                  animation: _fadeController,
                  builder: (_, child) => Opacity(
                    opacity: _fadeIn.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideIn.value),
                      child: child,
                    ),
                  ),
                  child: _LoginCard(
                    state: state,
                    vm: vm,
                    emailCtrl: _emailCtrl,
                    passwordCtrl: _passwordCtrl,
                    confirmCtrl: _confirmCtrl,
                    emailFocus: _emailFocus,
                    passwordFocus: _passwordFocus,
                    confirmFocus: _confirmFocus,
                    obscurePassword: _obscurePassword,
                    obscureConfirm: _obscureConfirm,
                    onTogglePassword: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    onToggleConfirm: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    onSubmit: () => _submit(vm, state),
                    onGoogle: () async {
                      final ok = await vm.signInWithGoogle();
                      if (kIsWeb && ok && mounted) _proceed();
                    },
                    onForgotPassword: () => _showForgotPassword(vm),
                    onToggleMode: () => _toggleMode(vm),
                    onSkip: () async {
                      await vm.skipLogin();
                      _proceed();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The glass card that holds all login UI
// ---------------------------------------------------------------------------
class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.state,
    required this.vm,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.emailFocus,
    required this.passwordFocus,
    required this.confirmFocus,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.onGoogle,
    required this.onForgotPassword,
    required this.onToggleMode,
    required this.onSkip,
  });

  final LoginState state;
  final LoginViewModel vm;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;
  final FocusNode confirmFocus;
  final bool obscurePassword;
  final bool obscureConfirm;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;
  final VoidCallback onForgotPassword;
  final VoidCallback onToggleMode;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand header
          _BrandHeader(),
          const SizedBox(height: 32),

          // Glass card
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF111827).withValues(alpha: 0.88),
                  const Color(0xFF0D1421).withValues(alpha: 0.95),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF00C2FF).withValues(alpha: 0.15),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00C2FF).withValues(alpha: 0.06),
                  blurRadius: 40,
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sign In / Sign Up tab switcher
                    _TabSwitcher(
                      isSignUp: state.isSignUp,
                      onToggle: onToggleMode,
                    ),
                    const SizedBox(height: 28),

                    // Subtitle
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        key: ValueKey(state.isSignUp),
                        state.isSignUp
                            ? 'Create an account to sync your focus\nsessions across all devices.'
                            : 'Welcome back! Sign in to continue your\nfocus journey.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Google button (prominent — at top like browser ext)
                    _GoogleButton(
                      isLoading: state.isLoading,
                      onTap: onGoogle,
                    ),

                    const SizedBox(height: 20),

                    // Divider
                    _OrDivider(),

                    const SizedBox(height: 20),

                    // Email field
                    _FancyTextField(
                      controller: emailCtrl,
                      focusNode: emailFocus,
                      hint: 'your@email.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    // Password field
                    _FancyTextField(
                      controller: passwordCtrl,
                      focusNode: passwordFocus,
                      hint: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscureText: obscurePassword,
                      onToggleObscure: onTogglePassword,
                    ),

                    // Forgot password
                    if (!state.isSignUp) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: onForgotPassword,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: GoogleFonts.dmSans(
                              color: AppColors.accentBlue.withValues(alpha: 0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Confirm password (sign up only)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeInOut,
                      child: state.isSignUp
                          ? Column(
                              children: [
                                const SizedBox(height: 12),
                                _FancyTextField(
                                  controller: confirmCtrl,
                                  focusNode: confirmFocus,
                                  hint: 'Confirm Password',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: obscureConfirm,
                                  onToggleObscure: onToggleConfirm,
                                ),
                                const SizedBox(height: 4),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 20),

                    // Submit button
                    _PrimaryButton(
                      label: state.isSignUp ? 'Create Account' : 'Sign In',
                      isLoading: state.isLoading,
                      onTap: state.isLoading ? null : onSubmit,
                    ),

                    // Error message
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: state.errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.accentRed
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.accentRed
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline_rounded,
                                        color: AppColors.accentRed, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        state.errorMessage!,
                                        style: GoogleFonts.dmSans(
                                          color: AppColors.accentRed,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Skip / guest link
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: Text(
                'Continue without account',
                style: GoogleFonts.dmSans(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand header with glow
// ---------------------------------------------------------------------------
class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Lightning bolt icon with glow
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF00C2FF), Color(0xFF0066CC)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00C2FF).withValues(alpha: 0.45),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.bolt_rounded, size: 38, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Text(
          'FocusEcho',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AI Focus Companion',
          style: GoogleFonts.dmSans(
            color: const Color(0xFF00C2FF),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sign In / Sign Up pill tab switcher
// ---------------------------------------------------------------------------
class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({required this.isSignUp, required this.onToggle});
  final bool isSignUp;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2D45)),
      ),
      child: Row(
        children: [
          _Tab(label: 'Sign In', active: !isSignUp, onTap: isSignUp ? onToggle : null),
          _Tab(label: 'Sign Up', active: isSignUp, onTap: isSignUp ? null : onToggle),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, this.onTap});
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF00C2FF).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? const Color(0xFF00C2FF).withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: active ? const Color(0xFF00C2FF) : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Google Sign-In button (prominent, at the top)
// ---------------------------------------------------------------------------
class _GoogleButton extends StatefulWidget {
  const _GoogleButton({required this.isLoading, required this.onTap});
  final bool isLoading;
  final VoidCallback onTap;

  @override
  State<_GoogleButton> createState() => _GoogleButtonState();
}

class _GoogleButtonState extends State<_GoogleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isLoading) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          boxShadow: _pressed
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: widget.isLoading
            ? const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.accentBlue,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _GoogleLogo(size: 22),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.dmSans(
                      color: const Color(0xFF1F1F1F),
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OR divider
// ---------------------------------------------------------------------------
class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: const Color(0xFF1E2D45)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: const Color(0xFF1E2D45)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fancy text field with glowing focus border
// ---------------------------------------------------------------------------
class _FancyTextField extends StatelessWidget {
  const _FancyTextField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.onToggleObscure,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final VoidCallback? onToggleObscure;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? const Color(0xFF00C2FF).withValues(alpha: 0.65)
              : const Color(0xFF1E2D45),
          width: focused ? 1.5 : 1.0,
        ),
        color: const Color(0xFF0A0E1A),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: const Color(0xFF00C2FF).withValues(alpha: 0.12),
                  blurRadius: 14,
                  spreadRadius: 0,
                )
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.dmSans(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(
            color: AppColors.textSecondary.withValues(alpha: 0.45),
            fontSize: 15,
          ),
          filled: false,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon,
              color: focused
                  ? const Color(0xFF00C2FF)
                  : AppColors.textSecondary.withValues(alpha: 0.5),
              size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primary submit button with gradient + glow
// ---------------------------------------------------------------------------
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: enabled
              ? const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF00C2FF)],
                )
              : null,
          color: enabled ? null : AppColors.surface,
          boxShadow: enabled && !_pressed
              ? [
                  BoxShadow(
                    color: const Color(0xFF00C2FF).withValues(alpha: 0.38),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
          border: enabled
              ? null
              : Border.all(color: AppColors.border),
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.dmSans(
                        color: enabled
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                    if (enabled) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animated dark gradient background
// ---------------------------------------------------------------------------
class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF080C18),
            Color(0xFF0A0E1A),
            Color(0xFF020617),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating orbs (slow rotation behind the card)
// ---------------------------------------------------------------------------
class _OrbLayer extends StatelessWidget {
  const _OrbLayer({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final angle = progress * 2 * math.pi;

    return Stack(
      children: [
        // Orb 1 — blue top-right
        Positioned(
          top: size.height * 0.08 + math.sin(angle) * 20,
          right: -size.width * 0.2 + math.cos(angle) * 20,
          child: _Orb(
            radius: size.width * 0.55,
            color: const Color(0xFF00C2FF),
            opacity: 0.07,
          ),
        ),
        // Orb 2 — purple bottom-left
        Positioned(
          bottom: size.height * 0.1 + math.cos(angle) * 18,
          left: -size.width * 0.25 + math.sin(angle) * 14,
          child: _Orb(
            radius: size.width * 0.6,
            color: const Color(0xFF7B61FF),
            opacity: 0.065,
          ),
        ),
        // Orb 3 — teal center-bottom
        Positioned(
          bottom: size.height * 0.35 + math.sin(angle * 0.7) * 12,
          right: size.width * 0.08,
          child: _Orb(
            radius: size.width * 0.3,
            color: const Color(0xFF00FFB2),
            opacity: 0.045,
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.radius,
    required this.color,
    required this.opacity,
  });

  final double radius;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius,
      height: radius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Forgot Password Dialog
// ---------------------------------------------------------------------------
class _ForgotPasswordDialog extends StatelessWidget {
  const _ForgotPasswordDialog({
    required this.emailCtrl,
    required this.onSend,
  });

  final TextEditingController emailCtrl;
  final Future<void> Function(String email) onSend;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF111827), Color(0xFF0D1421)],
          ),
          border: Border.all(
            color: const Color(0xFF00C2FF).withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: AppColors.accentBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Reset Password',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Enter your email and we'll send you a link to reset your password.",
              style: GoogleFonts.dmSans(
                color: AppColors.textSecondary,
                fontSize: 13.5,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            // Email field
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E2D45)),
                color: const Color(0xFF0A0E1A),
              ),
              child: TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'your@email.com',
                  hintStyle: GoogleFonts.dmSans(
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  prefixIcon: const Icon(Icons.email_outlined,
                      color: AppColors.accentBlue, size: 18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1E2D45)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.dmSans(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty) return;
                      onSend(email);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Send Link',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Google Logo painter
// ---------------------------------------------------------------------------
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 22});
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
    final sw = size.width * 0.22;
    final rect = Rect.fromCircle(center: center, radius: radius - sw / 2);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.35, 1.1, false, paint);

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.75, 1.4, false, paint);

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.15, 1.3, false, paint);

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.45, 1.5, false, paint);

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - sw / 2, radius, sw),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}