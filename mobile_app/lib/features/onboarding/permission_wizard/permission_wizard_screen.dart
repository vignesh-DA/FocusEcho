import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import 'permission_wizard_viewmodel.dart';

class PermissionWizardScreen extends ConsumerStatefulWidget {
  const PermissionWizardScreen({super.key});

  @override
  ConsumerState<PermissionWizardScreen> createState() => _PermissionWizardScreenState();
}

class _PermissionWizardScreenState extends ConsumerState<PermissionWizardScreen> {
  late AppLifecycleListener _lifecycleListener;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        ref.read(permissionWizardProvider.notifier).checkAllPermissions();
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(permissionWizardProvider);
    final vm = ref.read(permissionWizardProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('${state.currentPage + 1}/4', style: AppTextStyles.displayMedium),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _permissionPage(
                    icon: Icons.bar_chart_rounded,
                    title: 'Usage Access',
                    body:
                        'Focus Echo needs to see which app is in the foreground to detect distractions.',
                    button: 'Open Usage Access Settings',
                    granted: state.hasUsageAccess,
                    onTap: vm.openUsageAccessSettings,
                  ),
                  _permissionPage(
                    icon: Icons.accessibility_new_rounded,
                    title: 'Accessibility Service',
                    body: 'For instant app switch detection, enable Focus Echo in Accessibility Settings.',
                    button: 'Open Accessibility Settings',
                    granted: state.hasAccessibility,
                    onTap: vm.openAccessibilitySettings,
                  ),
                  _permissionPage(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Keep Focus Echo Running',
                    body: 'Disable battery optimization so the app is not killed in the background.',
                    button: 'Disable Battery Restriction',
                    granted: state.hasBatteryOptimization,
                    onTap: vm.requestBatteryOptimization,
                    secondaryButton: 'Open OEM Battery Settings (Xiaomi/Samsung)',
                    onSecondaryTap: vm.openManufacturerBatterySettings,
                  ),
                  _allSetPage(context, vm, state),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => vm.nextPage(_pageController, context),
                  child: const Text('Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _permissionPage({
    required IconData icon,
    required String title,
    required String body,
    required String button,
    required bool granted,
    required Future<void> Function() onTap,
    String? secondaryButton,
    Future<void> Function()? onSecondaryTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.accentBlue),
          const SizedBox(height: 16),
          Text(title, style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onTap, child: Text(button)),
          if (secondaryButton != null && onSecondaryTap != null) ...[
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onSecondaryTap, child: Text(secondaryButton)),
          ],
          const SizedBox(height: 12),
          Chip(
            backgroundColor: granted ? AppColors.accentGreen : AppColors.accentRed,
            label: Text(granted ? 'Granted' : 'Not Granted'),
          ),
        ],
      ),
    );
  }

  Widget _allSetPage(BuildContext context, PermissionWizardViewModel vm, dynamic state) {
    final allGranted = vm.isAllGranted;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.accentGreen, size: 80),
          const SizedBox(height: 16),
          Text("You're Ready!", style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'All permissions granted. Focus Echo will run reliably in the background.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 16),
          const ListTile(leading: Icon(Icons.check), title: Text('Usage Access granted')),
          const ListTile(leading: Icon(Icons.check), title: Text('Accessibility enabled')),
          const ListTile(leading: Icon(Icons.check), title: Text('Battery optimization disabled')),
          const SizedBox(height: 16),
          if (allGranted)
            ElevatedButton(
              onPressed: () {
                AppRouter.refresh(); // Trigger router re-evaluation
                context.go(AppRoutes.appSelector);
              },
              child: const Text('Start Using Focus Echo'),
            )
          else
            Column(
              children: [
                const Text('Some permissions are still missing.'),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: vm.checkAllPermissions, child: const Text('Check Again')),
              ],
            ),
        ],
      ),
    );
  }
}
