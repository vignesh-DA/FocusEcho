import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../distraction_alert/distraction_alert_modal.dart';
import '../distraction_alert/intervention_overlay.dart';
import 'focus_session_state.dart';
import 'focus_session_viewmodel.dart';
import 'session_summary_screen.dart';
import 'widgets/live_distraction_feed.dart';

class FocusSessionScreen extends ConsumerWidget {
  const FocusSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusSessionProvider);
    final vm = ref.read(focusSessionProvider.notifier);

    // Feature 2 — level-1 relapses keep the existing heads-up modal.
    ref.listen(focusSessionProvider, (previous, next) {
      final wasAlerting = previous?.showAlert ?? false;
      if (!wasAlerting &&
          next.showAlert &&
          next.lastEventId != null &&
          next.escalationLevel <= 1) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DistractionAlertModal(
            appName: next.lastDistractionLabel ??
                next.lastDistractionPackage ??
                'Unknown app',
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

    // Feature 4 — lightweight cross-surface nudge (non-blocking).
    ref.listen(focusSessionProvider, (previous, next) {
      final nudge = next.crossSurfaceNudge;
      if (nudge != null && nudge != (previous?.crossSurfaceNudge)) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.devices_other,
                      size: 18, color: AppColors.accentYellow),
                  const SizedBox(width: 8),
                  Expanded(child: Text(nudge)),
                ],
              ),
              backgroundColor: AppColors.card,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        vm.clearCrossSurfaceNudge();
      }
    });

    // Feature 1 — session-complete summary view.
    if (!state.isActive && state.sessionSummary != null) {
      return SessionSummaryScreen(
        summary: state.sessionSummary!,
        stats: state.sessionSummaryStats,
        onDismiss: vm.dismissSummary,
      );
    }

    if (!state.isActive) {
      return _SessionSetupView(state: state, vm: vm);
    }

    final elapsed = Duration(seconds: state.elapsedSeconds);
    final timer =
        '${elapsed.inHours.toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    // Feature 2 — level 2+ renders as a full-screen intervention state.
    final showFullScreenIntervention =
        state.showAlert && state.escalationLevel >= 2;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Bug 2 fix — FittedBox prevents the HH:MM:SS string from
                  // overflowing at narrow/mobile viewport widths.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      timer,
                      style: AppTextStyles.displayLarge
                          .copyWith(color: AppColors.accentGreen),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.98, end: 1.02),
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    onEnd: () {},
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppDecorations.glassmorphismCard(),
                      child: Column(
                        children: [
                          const Icon(Icons.apps_rounded, size: 48),
                          Text(state.session?.productiveApp ?? 'App',
                              style: AppTextStyles.displayMedium),
                          if (state.session?.intent.trim().isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 6),
                            Text(
                              '"${state.session!.intent.trim()}"',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.accentBlue,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Bug 2 fix — Flexible prevents right-edge clipping when
                      // the distraction count label grows long at small widths.
                      Flexible(
                        child: Text(
                          'Distractions: ${state.distractionCount}',
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.accentRed),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'XP: ${state.sessionXp}',
                          style: AppTextStyles.bodyLarge
                              .copyWith(color: AppColors.accentYellow),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (kIsWeb || state.liveDistractionFeed.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: LiveDistractionFeed(
                        feed: state.liveDistractionFeed,
                      ),
                    ),
                  ],
                  if (kIsWeb && !state.extensionConnected) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      color: AppColors.accentYellow.withValues(alpha: 0.15),
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          const Icon(Icons.extension_off,
                              color: AppColors.accentYellow, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Install the FocusEcho Chrome extension for real-time monitoring.',
                              style: const TextStyle(
                                  color: AppColors.accentYellow, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accentRed)),
                    onPressed: vm.stopSession,
                    child: const Text('STOP SESSION'),
                  ),
                ],
              ),
            ),
          ),
          if (showFullScreenIntervention)
            InterventionOverlay(
              level: state.escalationLevel,
              distractionCount: state.distractionCount,
              appName: state.lastDistractionLabel ??
                  state.lastDistractionPackage ??
                  'Unknown app',
              sessionIntent: state.session?.intent ?? state.intent,
              onReturnToFocus: vm.returnToFocusFromIntervention,
              onTakeBreak: vm.takeBreakFromIntervention,
              onPauseSession: vm.pauseSessionFromIntervention,
            ),
        ],
      ),
    );
  }
}

/// Feature 1 — setup view with the required Focus Intent step.
class _SessionSetupView extends StatelessWidget {
  const _SessionSetupView({required this.state, required this.vm});

  final FocusSessionState state;
  final FocusSessionViewModel vm;

  @override
  Widget build(BuildContext context) {
    final intent = state.intent;
    final canStart =
        state.selectedProductiveApp != null && intent.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Session'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/dashboard');
          }
        }),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.glassmorphismCard(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ready to Focus?',
                    style: AppTextStyles.displayLarge.copyWith(fontSize: 28)),
                const SizedBox(height: 16),
                Text('Select your productive app',
                    style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                if (state.availableProductiveApps.isEmpty)
                  Text('No apps selected. Go to Settings > App Selector.',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.accentRed))
                else
                  DropdownButton<String>(
                    value: state.selectedProductiveApp,
                    dropdownColor: AppColors.card,
                    isExpanded: true,
                    items: state.availableProductiveApps
                        .map((app) =>
                            DropdownMenuItem(value: app, child: Text(app)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) vm.selectProductiveApp(v);
                    },
                  ),
                const SizedBox(height: 20),
                // Feature 1 — required Focus Intent (max ~80 chars).
                Text('What is your focus intent?',
                    style: AppTextStyles.bodyLarge),
                const SizedBox(height: 6),
                TextField(
                  maxLength: 80,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'e.g. Finish the analytics dashboard',
                    counterText: '${intent.trim().length}/80',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: vm.setIntent,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: canStart
                      ? () => vm.startSession(
                            state.selectedProductiveApp!,
                            intent: intent,
                          )
                      : null,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: canStart
                          ? AppColors.accentBlue
                          : AppColors.textSecondary,
                      boxShadow: canStart
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.accentBlue.withValues(alpha: 0.4),
                                blurRadius: 24,
                              ),
                            ]
                          : const [],
                    ),
                    child: Center(
                      child: Text('START',
                          style: AppTextStyles.displayMedium
                              .copyWith(color: Colors.white)),
                    ),
                  ),
                ),
                if (!canStart) ...[
                  const SizedBox(height: 10),
                  Text(
                    state.selectedProductiveApp == null
                        ? 'Pick a productive app to begin.'
                        : 'Enter your intent above to unlock the start button.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.accentYellow),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
