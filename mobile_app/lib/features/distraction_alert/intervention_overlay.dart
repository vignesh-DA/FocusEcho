import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Feature 2 — full-screen escalating intervention state.
///
/// Level 2 (relapse 2-3): distraction count + session intent with
///   [Return to Focus] / [Take a Break].
/// Level 3 (relapse 4+): [Pause Session] / [Return to Focus] — no
///   dismiss-and-ignore option.
class InterventionOverlay extends StatelessWidget {
  const InterventionOverlay({
    super.key,
    required this.level,
    required this.distractionCount,
    required this.appName,
    required this.sessionIntent,
    required this.onReturnToFocus,
    required this.onTakeBreak,
    required this.onPauseSession,
  });

  final int level;
  final int distractionCount;
  final String appName;
  final String sessionIntent;
  final VoidCallback onReturnToFocus;
  final VoidCallback onTakeBreak;
  final VoidCallback onPauseSession;

  @override
  Widget build(BuildContext context) {
    final forced = level >= 3;
    final accent = forced ? AppColors.accentRed : Colors.orange;

    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: AppDecorations.neonCard(glowColor: accent),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  forced ? Icons.report_rounded : Icons.warning_rounded,
                  size: 72,
                  color: accent,
                ),
                const SizedBox(height: 12),
                Text(
                  forced ? 'Repeated drift detected' : 'Focus check',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displayMedium.copyWith(color: accent),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have drifted $distractionCount time(s) this session — '
                  'last: $appName.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge,
                ),
                if (sessionIntent.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.card.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Your goal: "${sessionIntent.trim()}"',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.accentBlue,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentGreen,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: onReturnToFocus,
                  icon: const Icon(Icons.center_focus_strong),
                  label: const Text('Return to Focus'),
                ),
                const SizedBox(height: 10),
                if (forced)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onPauseSession,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('Pause Session'),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onTakeBreak,
                    icon: const Icon(Icons.coffee),
                    label: const Text('Take a Break'),
                  ),
                if (!forced) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Ignoring is not an option at this level — choose one.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
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