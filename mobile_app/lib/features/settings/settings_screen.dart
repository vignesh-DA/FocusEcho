import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/app_dependencies.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/privacy_policy_sheet.dart';
import 'settings_viewmodel.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider);
    final vm = ref.read(settingsProvider.notifier);
    final authUser = AppDependencies.supabaseService.currentUser;
    final isAnonymous = authUser?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(title: Text('FOCUS PREFERENCES')),
          ListTile(
            title: const Text('Reminder strictness'),
            trailing: DropdownButton<String>(
              value: state.strictness,
              items: const [
                DropdownMenuItem(value: 'Gentle', child: Text('Gentle')),
                DropdownMenuItem(value: 'Normal', child: Text('Normal')),
                DropdownMenuItem(value: 'Strict', child: Text('Strict')),
              ],
              onChanged: (v) => v == null ? null : vm.updateStrictness(v),
            ),
          ),
          ListTile(
            title: const Text('Recovery countdown duration'),
            subtitle: Slider(
              min: 5,
              max: 30,
              divisions: 25,
              value: state.recoveryDuration.toDouble(),
              label: '${state.recoveryDuration}s',
              onChanged: (v) => vm.updateRecoveryDuration(v.toInt()),
            ),
          ),
          ListTile(
            title: const Text('Per-app time limits'),
            subtitle: const Text('Configure "Allowed with Limit" apps'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('${AppRoutes.settings}/app-limits'),
          ),
          const Divider(),
          const ListTile(title: Text('SYNC & PRIVACY')),
          SwitchListTile(
            title: const Text('Cloud sync'),
            value: state.cloudSyncEnabled,
            onChanged: state.localOnlyMode ? null : vm.updateCloudSync,
          ),
          SwitchListTile(
            title: const Text('Analytics sharing'),
            value: state.analyticsEnabled,
            onChanged: state.localOnlyMode ? null : vm.updateAnalytics,
          ),
          SwitchListTile(
            title: const Text('Local only mode'),
            value: state.localOnlyMode,
            onChanged: vm.updateLocalOnly,
          ),
          ListTile(
            title: const Text('Export My Data'),
            onTap: () => _dialog(
                context, 'Export My Data', 'Export is a placeholder for MVP.'),
          ),
          ListTile(
            title: const Text('Delete My Data'),
            trailing: state.isDeletingData
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            onTap: state.isDeletingData
                ? null
                : () => _confirmAndDelete(context, vm),
          ),
          const Divider(),
          const ListTile(title: Text('NOTIFICATIONS')),
          SwitchListTile(
            title: const Text('Enable nudge notifications'),
            value: state.nudgesEnabled,
            onChanged: vm.updateNudges,
          ),
          SwitchListTile(
            title: const Text('Enable streak reminders'),
            value: state.streakRemindersEnabled,
            onChanged: vm.updateStreakReminders,
          ),
          // Feature 4 — cross-surface intervention nudges (default off).
          SwitchListTile(
            title: const Text('Cross-device nudges'),
            subtitle: const Text(
              'Get a heads-up on this device when you drift on your other device. Requires a linked account.',
            ),
            value: state.crossSurfaceNudges,
            onChanged: (v) async {
              final error = await vm.updateCrossSurfaceNudges(v);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error)));
              }
            },
          ),
          ListTile(
            title: const Text('Daily summary time'),
            onTap: () =>
                showTimePicker(context: context, initialTime: TimeOfDay.now()),
          ),
          const Divider(),
          const ListTile(title: Text('ACCOUNT')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isAnonymous
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.person_outline,
                              color: AppColors.accentYellow),
                          const SizedBox(height: 8),
                          const Text(
                            'You are using an anonymous session. Link an email to sync your data across devices.',
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => context.go(AppRoutes.login),
                            child: const Text('Link Email Account →'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user,
                              color: AppColors.accentGreen),
                          const SizedBox(height: 8),
                          Text('Signed in as ${authUser?.email ?? 'Unknown'}'),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: state.isAuthenticating
                                ? null
                                : () => vm.signOut(),
                            child: const Text(
                              'Sign Out',
                              style: TextStyle(color: AppColors.accentRed),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const Divider(),
          const ListTile(title: Text('ABOUT')),
          const ListTile(title: Text('Version'), subtitle: Text('1.0.0')),
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const PrivacyPolicySheet(),
            ),
          ),
          ListTile(
            title: const Text('Open Source Licenses'),
            onTap: () => showLicensePage(context: context),
          ),
        ],
      ),
    );
  }

  void _dialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(
      BuildContext context, SettingsViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete My Data'),
        content: const Text(
          'This permanently deletes your local and cloud Focus Echo data for this account. This action cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final message = await vm.deleteMyData();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      context.go(AppRoutes.consent);
    } on StateError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
