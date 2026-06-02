import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../distraction_alert/distraction_alert_modal.dart';
import 'focus_session_viewmodel.dart';

class FocusSessionScreen extends ConsumerWidget {
  const FocusSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusSessionProvider);
    final vm = ref.read(focusSessionProvider.notifier);

    ref.listen(focusSessionProvider, (previous, next) {
      if ((previous?.showAlert ?? false) == false && next.showAlert && next.lastEventId != null) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DistractionAlertModal(
            appName: next.lastDistractionLabel ?? next.lastDistractionPackage ?? 'Unknown app',
            packageName: next.lastDistractionPackage ?? 'unknown',
            riskScore: next.currentRiskScore,
            onRecovery: () => vm.onRecovery(next.lastEventId!),
            onEndSession: vm.stopSession,
            onSnooze: () => vm.snoozeApp(next.lastDistractionPackage!),
            onStreakPenalty: vm.dismissAlert,
          ),
        );
      }
    });

    if (!state.isActive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Focus Session'),
          leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        ),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.glassmorphismCard(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ready to Focus?', style: AppTextStyles.displayLarge.copyWith(fontSize: 28)),
                const SizedBox(height: 16),
                Text('Select your productive app', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                if (state.availableProductiveApps.isEmpty)
                  Text('No apps selected. Go to Settings > App Selector.',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accentRed))
                else
                  DropdownButton<String>(
                    value: state.selectedProductiveApp,
                    dropdownColor: AppColors.card,
                    items: state.availableProductiveApps
                        .map((app) => DropdownMenuItem(value: app, child: Text(app)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) vm.selectProductiveApp(v);
                    },
                  ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: state.selectedProductiveApp == null
                      ? null
                      : () => vm.startSession(state.selectedProductiveApp!),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.selectedProductiveApp != null
                          ? AppColors.accentBlue
                          : AppColors.textSecondary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentBlue.withValues(alpha: 0.4),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text('START',
                          style: AppTextStyles.displayMedium.copyWith(color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final elapsed = Duration(seconds: state.elapsedSeconds);
    final timer =
        '${elapsed.inHours.toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(timer, style: AppTextStyles.displayLarge.copyWith(color: AppColors.accentGreen)),
              const SizedBox(height: 28),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.98, end: 1.02),
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                onEnd: () {},
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppDecorations.glassmorphismCard(),
                  child: Column(
                    children: [
                      const Icon(Icons.apps_rounded, size: 48),
                      Text(state.session?.productiveApp ?? 'App', style: AppTextStyles.displayMedium),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Distractions: ${state.distractionCount}',
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.accentRed)),
                  Text('XP: ${state.sessionXp}',
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.accentYellow)),
                ],
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentRed.withValues(alpha: 0.2),
                    foregroundColor: AppColors.accentRed,
                    side: const BorderSide(color: AppColors.accentRed),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () => vm.onDistractionDetected('com.instagram.android', 'Instagram'),
                  icon: const Icon(Icons.warning_amber_rounded),
                  label: const Text('Simulate Distraction (Web Demo)'),
                ),
              ],
              const Spacer(),
              OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.accentRed)),
                onPressed: vm.stopSession,
                child: const Text('STOP SESSION'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
