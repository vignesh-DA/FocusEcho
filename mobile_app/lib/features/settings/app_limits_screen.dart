import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'settings_viewmodel.dart';

class AppLimitsScreen extends ConsumerWidget {
  const AppLimitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final vm = ref.read(settingsProvider.notifier);

    // For simplicity, we'll show limits for apps that already have one,
    // plus a way to add a new one. In a real app, you'd pick from installed apps.
    final appsWithLimits = settings.appLimits.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Per-App Time Limits'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Set how long you can use "Limited" apps before they count as a distraction.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 20),
          if (appsWithLimits.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.timer_off_outlined, size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text('No limits set yet', style: AppTextStyles.bodyLarge),
                  ],
                ),
              ),
            ),
          ...appsWithLimits.map((pkg) => _AppLimitTile(
                packageName: pkg,
                seconds: settings.appLimits[pkg]!,
                onChanged: (val) => vm.updateAppLimit(pkg, val),
              )),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showAddLimitDialog(context, vm),
            icon: const Icon(Icons.add),
            label: const Text('Add App Limit'),
          ),
        ],
      ),
    );
  }

  void _showAddLimitDialog(BuildContext context, SettingsViewModel vm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add App Limit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Package Name (e.g. com.android.chrome)',
                hintText: 'com.example.app',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Default limit is 15 seconds. You can adjust it after adding.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                vm.updateAppLimit(controller.text, 15);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _AppLimitTile extends StatelessWidget {
  const _AppLimitTile({
    required this.packageName,
    required this.seconds,
    required this.onChanged,
  });

  final String packageName;
  final int seconds;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.glassmorphismCard(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(packageName, style: AppTextStyles.bodyLarge, overflow: TextOverflow.ellipsis),
                Text('Limit: $seconds seconds', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppColors.accentRed),
            onPressed: () => onChanged(0),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: [15, 30, 60, 120, 300].contains(seconds) ? seconds : 15,
            dropdownColor: AppColors.card,
            items: const [
              DropdownMenuItem(value: 15, child: Text('15s')),
              DropdownMenuItem(value: 30, child: Text('30s')),
              DropdownMenuItem(value: 60, child: Text('1m')),
              DropdownMenuItem(value: 120, child: Text('2m')),
              DropdownMenuItem(value: 300, child: Text('5m')),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
