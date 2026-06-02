import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'analytics_viewmodel.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);
    final vm = ref.read(analyticsProvider.notifier);
    final appEntries = state.appDistribution.entries.take(5).toList();
    final pieColors = [
      AppColors.accentBlue,
      AppColors.accentGreen,
      AppColors.accentRed,
      AppColors.accentYellow,
      AppColors.textSecondary,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: vm.loadAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.errorMessage != null) ...[
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
                const SizedBox(height: 12),
              ],
              Text('Weekly Focus Time', style: AppTextStyles.displayMedium),
              SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    barGroups: List.generate(7, (i) {
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: state.weeklyFocusMinutes[i],
                            gradient: LinearGradient(
                              colors: [AppColors.accentBlue.withValues(alpha: 0.6), AppColors.accentBlue],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Daily Distractions', style: AppTextStyles.displayMedium),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          7,
                          (i) => FlSpot(i.toDouble(), state.dailyDistractions[i].toDouble()),
                        ),
                        color: AppColors.accentRed,
                        isCurved: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Most Distracting Apps', style: AppTextStyles.displayMedium),
              if (appEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No distraction data yet.', style: AppTextStyles.bodyMedium),
                  ),
                )
              else ...[
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: List.generate(appEntries.length, (i) {
                        final e = appEntries[i];
                        return PieChartSectionData(
                          color: pieColors[i % pieColors.length],
                          value: e.value.toDouble(),
                          title: '${e.value}',
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(appEntries.length, (i) {
                  final e = appEntries[i];
                  return Row(
                    children: [
                      Container(width: 10, height: 10, color: pieColors[i % pieColors.length]),
                      const SizedBox(width: 8),
                      Text(e.key),
                    ],
                  );
                }),
              ],
              const SizedBox(height: 16),
              Text('Focus Score History', style: AppTextStyles.displayMedium),
              if (state.sessionScores.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Complete sessions to see your trend.', style: AppTextStyles.bodyMedium),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            state.sessionScores.length,
                            (i) => FlSpot(i.toDouble(), state.sessionScores[i]),
                          ),
                          color: AppColors.accentGreen,
                          isCurved: true,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
