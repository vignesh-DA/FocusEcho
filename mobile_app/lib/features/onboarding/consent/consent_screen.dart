import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/privacy_policy_sheet.dart';
import 'consent_viewmodel.dart';

class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consentProvider);
    final vm = ref.read(consentProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    const Icon(Icons.graphic_eq_rounded, color: AppColors.accentBlue, size: 72),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppStrings.appName,
                      style: AppTextStyles.displayLarge.copyWith(
                        color: AppColors.accentBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      AppStrings.appSubtitle,
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      decoration: AppDecorations.glassmorphismCard(),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section('What we monitor', 'Only the productive apps you select.'),
                          _section(
                            'What we never do',
                            'Read messages, access personal files, or share data without consent.',
                          ),
                          _section('Local-only mode', 'You can choose to keep all data on-device.'),
                          const SizedBox(height: AppSpacing.md),
                          Material(
                            color: Colors.transparent,
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: const Text('Enable analytics'),
                                  value: state.analyticsEnabled,
                                  onChanged: vm.toggleAnalytics,
                                ),
                                SwitchListTile(
                                  title: const Text('Enable cloud sync'),
                                  value: state.cloudSyncEnabled,
                                  onChanged: state.localOnlyMode ? null : vm.toggleCloudSync,
                                ),
                                SwitchListTile(
                                  title: const Text('Local only mode'),
                                  value: state.localOnlyMode,
                                  onChanged: vm.toggleLocalOnly,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: AppDecorations.accentButton(AppColors.accentBlue),
                      child: ElevatedButton(
                        onPressed: state.isSaving
                            ? null
                            : () async {
                                await vm.saveConsent();
                                AppRouter.refresh();
                                if (context.mounted) context.go(AppRoutes.permissionWizard);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('I Agree & Continue'),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const PrivacyPolicySheet(),
                    ),
                    child: const Text('Privacy Policy'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
