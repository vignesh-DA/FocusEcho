import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class CoachOptInDialog extends StatelessWidget {
  const CoachOptInDialog({
    super.key,
    required this.onOptInChanged,
    this.currentOptIn = false,
  });

  final ValueChanged<bool> onOptInChanged;
  final bool currentOptIn;

  static Future<bool?> show(BuildContext context, {bool currentOptIn = false}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CoachOptInDialog(
        currentOptIn: currentOptIn,
        onOptInChanged: (val) => Navigator.of(ctx).pop(val),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(24),
        decoration: AppDecorations.glassmorphismCard().copyWith(
          border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.accentBlue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EchoCoach Transparency',
                          style: AppTextStyles.displayMedium.copyWith(fontSize: 20),
                        ),
                        Text(
                          'Private, objective focus insights',
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildRow(
                      icon: Icons.lock_outline_rounded,
                      iconColor: AppColors.accentGreen,
                      title: 'Zero Tab or Page Content',
                      description:
                          'EchoCoach NEVER sees your URLs, searches, page text, keystrokes, or documents.',
                    ),
                    const Divider(color: AppColors.border, height: 20),
                    _buildRow(
                      icon: Icons.data_usage_rounded,
                      iconColor: AppColors.accentBlue,
                      title: 'What EchoCoach Analyzes',
                      description:
                          'Only aggregates: hostname (e.g. youtube.com), session duration, distraction minute offsets, and your typed intention.',
                    ),
                    const Divider(color: AppColors.border, height: 20),
                    _buildRow(
                      icon: Icons.verified_user_outlined,
                      iconColor: AppColors.accentYellow,
                      title: 'Enterprise Paid Tier',
                      description:
                          'Telemetry is processed via paid enterprise APIs that never use your data for model training.',
                    ),
                    const Divider(color: AppColors.border, height: 20),
                    _buildRow(
                      icon: Icons.ac_unit_rounded,
                      iconColor: AppColors.textSecondary,
                      title: 'Cold-Start Protection',
                      description:
                          'Under 5 sessions, no personal habit claims are made. Only session arithmetic is reported.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => onOptInChanged(false),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => onOptInChanged(true),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: Text(
                        currentOptIn ? 'Keep Enabled' : 'Enable EchoCoach',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyLarge.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
