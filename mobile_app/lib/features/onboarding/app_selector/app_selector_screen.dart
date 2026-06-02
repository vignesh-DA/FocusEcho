import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import 'app_selector_viewmodel.dart';

class AppSelectorScreen extends ConsumerWidget {
  const AppSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appSelectorProvider);
    final vm = ref.read(appSelectorProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text('Select Your Apps', style: AppTextStyles.displayMedium)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Productive Apps',
                      style: AppTextStyles.displayMedium.copyWith(color: AppColors.accentGreen)),
                  const SizedBox(height: 12),
                  _buildGrid(
                    AppSelectorViewModel.productiveApps,
                    state.selectedProductiveApps,
                    vm.toggleProductiveApp,
                  ),
                  const Divider(height: 32),
                  Text('Distracting Apps',
                      style: AppTextStyles.displayMedium.copyWith(color: AppColors.accentRed)),
                  const SizedBox(height: 12),
                  _buildGrid(
                    AppSelectorViewModel.distractingApps,
                    state.selectedDistractingApps,
                    vm.toggleDistractingApp,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: vm.isValid
                      ? () async {
                          await vm.saveSelection();
                          if (context.mounted) context.go(AppRoutes.dashboard);
                        }
                      : null,
                  child: const Text('Save & Continue'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(
    Map<String, String> apps,
    Set<String> selected,
    void Function(String packageName) toggle,
  ) {
    return GridView.builder(
      itemCount: apps.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (context, index) {
        final package = apps.keys.elementAt(index);
        final name = apps[package]!;
        final checked = selected.contains(package);
        return InkWell(
          onTap: () => toggle(package),
          child: Container(
            decoration: AppDecorations.glassmorphismCard(),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                Checkbox(value: checked, onChanged: (_) => toggle(package)),
              ],
            ),
          ),
        );
      },
    );
  }
}
