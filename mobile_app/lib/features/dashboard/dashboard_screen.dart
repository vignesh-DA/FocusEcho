import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'dashboard_viewmodel.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final vm = ref.read(dashboardProvider.notifier);
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'morning' : (now.hour < 18 ? 'afternoon' : 'evening');
    final name = state.userProfile?.displayName ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: vm.loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good $greeting, $name', style: AppTextStyles.displayMedium.copyWith(fontSize: 22)),
                Text(
                  state.userProfile?.computedLevelTitle ?? AppStrings.level1,
                  style: AppTextStyles.bodyLarge.copyWith(color: AppColors.accentBlue),
                ),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(state.errorMessage!,
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accentRed)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppDecorations.glassmorphismCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${state.userProfile?.totalXp ?? 0} XP', style: AppTextStyles.displayMedium),
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(value: 0.45),
                      const SizedBox(height: 8),
                      const Text('Next: Consistency Pro • 250 XP needed'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statCard('Sessions', '${state.todaySessions.length}'),
                    const SizedBox(width: 8),
                    _statCard('Focus Min', '${state.totalFocusMinutesToday}'),
                    const SizedBox(width: 8),
                    _statCard('Avoided', '${state.todayDistractionCount}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Feature 3 — Recovery Rate promoted to a headline stat
                    // next to the focus streak, with week-over-week trend.
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppDecorations.glassmorphismCard(),
                        child: Column(
                          children: [
                            const Icon(Icons.speed, color: AppColors.accentGreen, size: 40),
                            Text('${state.recoveryRate.toStringAsFixed(0)}%',
                                style: AppTextStyles.displayLarge.copyWith(fontSize: 32)),
                            Text('Recovery Rate', style: AppTextStyles.bodyMedium),
                            const SizedBox(height: 4),
                            Text(
                              state.recoveryRateTrend >= 0
                                  ? '▲ +${state.recoveryRateTrend.toStringAsFixed(1)} pts vs last week'
                                  : '▼ ${state.recoveryRateTrend.toStringAsFixed(1)} pts vs last week',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: state.recoveryRateTrend >= 0
                                    ? AppColors.accentGreen
                                    : AppColors.accentRed,
                              ),
                            ),
                            if (state.medianRecoverySeconds > 0)
                              Text(
                                'Median return: ${state.medianRecoverySeconds.toStringAsFixed(0)}s',
                                style: AppTextStyles.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppDecorations.glassmorphismCard(),
                        child: Column(
                          children: [
                            const Icon(Icons.local_fire_department, color: AppColors.accentYellow, size: 40),
                            Text('${state.userProfile?.streakDays ?? 0} Day Streak',
                                style: AppTextStyles.displayLarge.copyWith(fontSize: 28)),
                            Text('Personal Best: ${state.userProfile?.longestStreak ?? 0} days',
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: AppDecorations.accentButton(AppColors.accentBlue),
                    child: ElevatedButton(
                      onPressed: () => context.go(AppRoutes.focusSession),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                      ),
                      child: const Text('Start Focus Session →'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Recent Sessions', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                if (state.todaySessions.isEmpty && !state.isLoading)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No sessions today. Start one!', style: AppTextStyles.bodyMedium),
                    ),
                  )
                else
                  ...state.todaySessions.take(5).map(
                        (s) => Card(
                          child: ListTile(
                            title: Text(s.productiveApp),
                            subtitle: Text(DateFormat('MMM d, HH:mm').format(s.startTime)),
                            trailing: Text('${s.totalXpEarned} XP • ${s.focusScore.toStringAsFixed(0)}'),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: AppDecorations.glassmorphismCard(),
        child: Column(
          children: [Text(value, style: AppTextStyles.displayMedium), Text(label)],
        ),
      ),
    );
  }
}
