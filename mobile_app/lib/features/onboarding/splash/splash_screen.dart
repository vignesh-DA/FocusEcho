import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..forward();
    Timer(const Duration(milliseconds: 2500), _goNext);
  }

  Future<void> _goNext() async {
    final prefs = await SharedPreferences.getInstance();
    final consentGiven = prefs.getBool(AppKeys.consentGiven) ?? false;
    final usage = prefs.getBool('has_usage_access') ?? false;
    final accessibility = prefs.getBool('has_accessibility') ?? false;
    final battery = prefs.getBool('has_battery_optimization') ?? false;
    if (!mounted) return;
    if (!consentGiven) {
      context.go(AppRoutes.consent);
      return;
    }

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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: CurvedAnimation(parent: _controller, curve: const Interval(0, 0.25)),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1).animate(
                  CurvedAnimation(parent: _controller, curve: const Interval(0.25, 0.5)),
                ),
                child: const Icon(Icons.graphic_eq_rounded, size: 80, color: AppColors.accentBlue),
              ),
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.5, 0.75)),
              child: Text(
                'Focus Echo AI',
                style: AppTextStyles.displayLarge.copyWith(color: AppColors.accentBlue),
              ),
            ),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: CurvedAnimation(parent: _controller, curve: const Interval(0.75, 1)),
              child: Text('Take back your focus', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
