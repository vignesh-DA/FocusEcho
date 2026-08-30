import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../distraction_alert/distraction_alert_modal.dart';
import '../distraction_alert/intervention_overlay.dart';
import 'focus_session_state.dart';
import 'focus_session_viewmodel.dart';

class FocusSessionScreen extends ConsumerWidget {
  const FocusSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(focusSessionProvider);
    final vm = ref.read(focusSessionProvider.notifier);

    // Feature 2 — level-1 relapses keep the existing heads-up modal.
    ref.listen(focusSessionProvider, (previous, next) {
      final wasAlerting = previous?.showAlert ?? false;
      if (!wasAlerting && next.showAlert && next.lastEventId != null && next.escalationLevel <= 1) {
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
                  const Icon(Icons.devices_other, size: 18, color: AppColors.accentYellow),
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
      return _SessionSummaryView(summary: state.sessionSummary!, onDismiss: vm.dismissSummary);
    }

    if (!state.isActive) {
      return _SessionSetupView(state: state, vm: vm);
    }

    final elapsed = Duration(seconds: state.elapsedSeconds);
    final timer =
        '${elapsed.inHours.toString().padLeft(2, '0')}:${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';

    // Feature 2 — level 2+ renders as a full-screen intervention state.
    final showFullScreenIntervention = state.showAlert && state.escalationLevel >= 2;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
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
                          if (state.session?.intent.trim().isNotEmpty ?? false) ...[
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
          if (showFullScreenIntervention)
            InterventionOverlay(
              level: state.escalationLevel,
              distractionCount: state.distractionCount,
              appName: state.lastDistractionLabel ?? state.lastDistractionPackage ?? 'Unknown app',
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
    final canStart = state.selectedProductiveApp != null && intent.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Session'),
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
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
                    isExpanded: true,
                    items: state.availableProductiveApps
                        .map((app) => DropdownMenuItem(value: app, child: Text(app)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) vm.selectProductiveApp(v);
                    },
                  ),
                const SizedBox(height: 20),
                // Feature 1 — required Focus Intent (max ~80 chars).
                Text('What is your focus intent?', style: AppTextStyles.bodyLarge),
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
                      color: canStart ? AppColors.accentBlue : AppColors.textSecondary,
                      boxShadow: canStart
                          ? [
                              BoxShadow(
                                color: AppColors.accentBlue.withValues(alpha: 0.4),
                                blurRadius: 24,
                              ),
                            ]
                          : const [],
                    ),
                    child: Center(
                      child: Text('START',
                          style: AppTextStyles.displayMedium.copyWith(color: Colors.white)),
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
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accentYellow),
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

/// Feature 1 — session-complete view: intent + planned vs. actual duration.
class _SessionSummaryView extends StatelessWidget {
  const _SessionSummaryView({required this.summary, required this.onDismiss});

  final SessionSummary summary;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final actual = Duration(seconds: summary.actualSeconds);
    final actualText = '${actual.inMinutes}m ${actual.inSeconds % 60}s';

    return Scaffold(
      appBar: AppBar(title: const Text('Session Complete')),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: AppDecorations.glassmorphismCard(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.emoji_events_outlined, size: 56, color: AppColors.accentYellow),
              const SizedBox(height: 12),
              Text('Session Complete', textAlign: TextAlign.center,
                  style: AppTextStyles.displayLarge.copyWith(fontSize: 26)),
              const SizedBox(height: 16),
              if (summary.intent.trim().isNotEmpty) ...[
                Text('Your intent', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  '"${summary.intent}"',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.accentBlue,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Planned focus', style: AppTextStyles.bodyMedium),
                        Text(summary.productiveApp, style: AppTextStyles.bodyLarge),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Actual duration', style: AppTextStyles.bodyMedium),
                        Text(actualText, style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _summaryStat('${summary.totalDistractions}', 'Distractions', AppColors.accentRed),
                  _summaryStat('${summary.sessionXp}', 'XP', AppColors.accentYellow),
                  _summaryStat(
                    summary.focusScore.toStringAsFixed(0),
                    'Focus Score',
                    AppColors.accentGreen,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onDismiss,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.displayMedium.copyWith(color: color)),
        Text(label, style: AppTextStyles.bodyMedium),
      ],
    );
  }
}