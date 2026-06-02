import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'streaks_xp_viewmodel.dart';

class StreaksXpScreen extends ConsumerWidget {
  const StreaksXpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(streaksXpProvider);
    final xp = state.userProfile?.totalXp ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Streaks & XP')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: xp.toDouble()),
              duration: const Duration(milliseconds: 600),
              builder: (_, value, __) => Text(
                '${value.toInt()} XP',
                style: AppTextStyles.displayLarge.copyWith(fontSize: 40),
              ),
            ),
            const SizedBox(height: 12),
            _levelCard(state.userProfile?.computedLevelTitle ?? 'Focus Rookie'),
            const SizedBox(height: 12),
            Text('XP to next level: ${state.xpToNextLevel}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: state.progressPercent),
            const SizedBox(height: 16),
            Text('Milestones', style: AppTextStyles.displayMedium),
            const ListTile(leading: Icon(Icons.lock_open), title: Text('Level 1 • 0 XP')),
            const ListTile(leading: Icon(Icons.lock), title: Text('Level 2 • 500 XP')),
            const ListTile(leading: Icon(Icons.lock), title: Text('Level 3 • 1500 XP')),
            const ListTile(leading: Icon(Icons.lock), title: Text('Level 4 • 3500 XP')),
            const SizedBox(height: 12),
            Text('7-Day Streak Calendar', style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Row(
              children: List.generate(7, (i) {
                final active = state.weeklyActivity[i];
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 36,
                    decoration: BoxDecoration(
                      color: active ? AppColors.accentGreen : AppColors.accentRed.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Text('Achievements', style: AppTextStyles.displayMedium),
            Wrap(
              spacing: 8,
              children: const [
                Chip(label: Text('First Session 🔒')),
                Chip(label: Text('7 Day Streak 🔒')),
                Chip(label: Text('1000 XP 🔒')),
                Chip(label: Text('No Distractions 🔒')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _levelCard(String levelTitle) {
    IconData icon = Icons.school_rounded;
    Color color = AppColors.textSecondary;
    if (levelTitle == 'Consistency Pro') {
      icon = Icons.trending_up_rounded;
      color = AppColors.accentBlue;
    } else if (levelTitle == 'Flow Master') {
      icon = Icons.bolt_rounded;
      color = AppColors.accentYellow;
    } else if (levelTitle == 'Zen Monk') {
      icon = Icons.self_improvement_rounded;
      color = AppColors.accentGreen;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassmorphismCard(),
      child: Row(
        children: [
          Icon(icon, size: 42, color: color),
          const SizedBox(width: 12),
          Text(levelTitle, style: AppTextStyles.displayMedium),
        ],
      ),
    );
  }
}
