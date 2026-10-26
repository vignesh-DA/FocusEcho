import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/backend_analytics_service.dart';
import 'analytics_viewmodel.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _pieColors = [
    Color(0xFF6366F1),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF06B6D4),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analyticsProvider);
    final vm = ref.read(analyticsProvider.notifier);
    final appEntries = state.appDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topApps = appEntries.take(5).toList();

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
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.accentRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(state.errorMessage!,
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.accentRed)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // MOB-3g — Remote backend summary card (shows only when loaded)
              if (state.isRemoteLoaded) ...[
                _RemoteSummaryCard(state: state),
                const SizedBox(height: 16),
              ],

              // ── Weekly Focus Time ────────────────────────────────────────
              Text('Weekly Focus Time', style: AppTextStyles.displayMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: Builder(
                  builder: (context) {
                    final maxMins = state.weeklyFocusMinutes.reduce((a, b) => a > b ? a : b);
                    final maxY = (maxMins * 1.25).clamp(10, double.infinity).toDouble();
                    return BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final day = _days[group.x.toInt() % _days.length];
                              return BarTooltipItem(
                                '$day: ${rod.toY.toInt()}m focus',
                                AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        barGroups: List.generate(7, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: state.weeklyFocusMinutes[i],
                                width: 20,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                gradient: const LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF06B6D4),
                                  ],
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                            ],
                          );
                        }),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.max) return const SizedBox();
                                return Text(
                                  '${value.toInt()}m',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textSecondary, fontSize: 10),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx < 0 || idx >= _days.length) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _days[idx],
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textSecondary, fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => const FlLine(
                            color: Colors.white10,
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // ── Daily Distractions ──────────────────────────────────────
              Text('Daily Distractions', style: AppTextStyles.displayMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 6,
                    minY: 0,
                    maxY: (state.dailyDistractions
                                .reduce((a, b) => a > b ? a : b)
                                .toDouble() *
                            1.3)
                        .clamp(4, double.infinity),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final day = _days[spot.x.toInt() % _days.length];
                            return LineTooltipItem(
                              '$day: ${spot.y.toInt()} distraction${spot.y.toInt() == 1 ? '' : 's'}',
                              AppTextStyles.bodySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          7,
                          (i) => FlSpot(i.toDouble(),
                              state.dailyDistractions[i].toDouble()),
                        ),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF5E62), Color(0xFFFF9966)],
                        ),
                        isCurved: true,
                        preventCurveOverShooting: true,
                        barWidth: 3.0,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, _, __, ___) =>
                              FlDotCirclePainter(
                            radius: 3.5,
                            color: const Color(0xFFFF5E62),
                            strokeColor: Colors.white,
                            strokeWidth: 1.5,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFFF5E62).withValues(alpha: 0.28),
                              const Color(0xFFFF9966).withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= _days.length) return const SizedBox();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                _days[idx],
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary, fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value != value.roundToDouble()) return const SizedBox();
                            if (value == meta.max) return const SizedBox();
                            return Text(
                              value.toInt().toString(),
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary, fontSize: 10),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (v) =>
                          const FlLine(color: Colors.white10, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Most Distracting Apps (donut) ───────────────────────────
              Text('Most Distracting Apps', style: AppTextStyles.displayMedium),
              const SizedBox(height: 8),
              if (topApps.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No distraction data yet.',
                        style: AppTextStyles.bodyMedium),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // ── Donut with center label ────────────────────────
                      Builder(builder: (context) {
                        final total = topApps.fold<int>(0, (s, x) => s + x.value);
                        return SizedBox(
                          height: 160,
                          width: 160,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  centerSpaceRadius: 48,
                                  sectionsSpace: 3,
                                  startDegreeOffset: -90,
                                  sections: List.generate(topApps.length, (i) {
                                    return PieChartSectionData(
                                      color: _pieColors[i % _pieColors.length],
                                      value: topApps[i].value.toDouble(),
                                      title: '',           // no text inside slice
                                      radius: 52,
                                      borderSide: const BorderSide(
                                        color: Colors.transparent,
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              // Centre total label
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$total',
                                    style: AppTextStyles.displayMedium.copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'total',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(width: 18),

                      // ── Premium legend with mini bars ─────────────────
                      Expanded(
                        child: Builder(builder: (context) {
                          final total = topApps.fold<int>(0, (s, x) => s + x.value);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(topApps.length, (i) {
                              final e = topApps[i];
                              final pct = total > 0 ? e.value / total : 0.0;
                              final color = _pieColors[i % _pieColors.length];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            e.key,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              fontSize: 11,
                                              color: Colors.white,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${(pct * 100).round()}%',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            fontSize: 10,
                                            color: color,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Mini progress bar
                                    LayoutBuilder(builder: (ctx, constraints) {
                                      return Stack(
                                        children: [
                                          Container(
                                            height: 3,
                                            width: constraints.maxWidth,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          Container(
                                            height: 3,
                                            width: constraints.maxWidth * pct,
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],


              // MOB-3g — Remote top apps
              if (state.remoteTopApps.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RemoteTopAppsSection(apps: state.remoteTopApps),
              ],

              const SizedBox(height: 20),

              // ── Focus Score History ─────────────────────────────────────
              Text('Focus Score History', style: AppTextStyles.displayMedium),
              const SizedBox(height: 8),
              if (state.sessionScores.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('Complete sessions to see your trend.',
                        style: AppTextStyles.bodyMedium),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              return LineTooltipItem(
                                'Session #${spot.x.toInt() + 1}: ${spot.y.toInt()} Score',
                                AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            state.sessionScores.length,
                            (i) => FlSpot(
                                i.toDouble(), state.sessionScores[i]),
                          ),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF34D399)],
                          ),
                          isCurved: true,
                          preventCurveOverShooting: true,
                          barWidth: 3.0,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, __, ___) =>
                                FlDotCirclePainter(
                              radius: 3.5,
                              color: const Color(0xFF10B981),
                              strokeColor: Colors.white,
                              strokeWidth: 1.5,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF10B981).withValues(alpha: 0.25),
                                const Color(0xFF34D399).withValues(alpha: 0.02),
                              ],
                            ),
                          ),
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 25,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max) return const SizedBox();
                              return Text(
                                value.toInt().toString(),
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) => Text(
                              '#${value.toInt() + 1}',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary, fontSize: 10),
                            ),
                          ),
                        ),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (v) =>
                            const FlLine(color: Colors.white10, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                ),

              // MOB-3g — Risk trend
              if (state.remoteRiskTrend.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RiskTrendSection(trend: state.remoteRiskTrend),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Remote backend widgets (MOB-3g) ──────────────────────────────────────────


class _RemoteSummaryCard extends StatelessWidget {
  const _RemoteSummaryCard({required this.state});
  final AnalyticsState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassmorphismCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_done_outlined,
                  size: 16, color: AppColors.accentGreen),
              const SizedBox(width: 6),
              Text('Backend Summary',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.accentGreen)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SummaryChip(
                label: 'Avg Focus Score',
                value: state.remoteFocusScoreAverage != null
                    ? state.remoteFocusScoreAverage!.toStringAsFixed(1)
                    : '—',
              ),
              _SummaryChip(
                label: 'Synced Sessions',
                value: state.remoteWeeklySessions?.toString() ?? '—',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.displayMedium),
        Text(label,
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

class _RemoteTopAppsSection extends StatelessWidget {
  const _RemoteTopAppsSection({required this.apps});
  final List<TopApp> apps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Top Distractions (Synced)',
                style: AppTextStyles.displayMedium),
            const SizedBox(width: 6),
            const Icon(Icons.cloud_outlined,
                size: 14, color: AppColors.accentBlue),
          ],
        ),
        const SizedBox(height: 8),
        ...apps.map(
          (app) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: Text(app.label)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${app.count}×',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.accentRed)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RiskTrendSection extends StatelessWidget {
  const _RiskTrendSection({required this.trend});
  final List<RiskDayEntry> trend;

  @override
  Widget build(BuildContext context) {
    // Count HIGH/CRITICAL per day for a sleek curved area chart
    final riskByDay = trend.map((d) {
      final high = d.riskScores
          .where((r) => r == 'HIGH' || r == 'CRITICAL')
          .length;
      return FlSpot(trend.indexOf(d).toDouble(), high.toDouble());
    }).toList();

    final totalHighRisk = trend.fold<int>(
      0,
      (s, d) => s + d.riskScores.where((r) => r == 'HIGH' || r == 'CRITICAL').length,
    );
    final riskLabel = totalHighRisk == 0
        ? 'Low Risk'
        : totalHighRisk <= 3
            ? 'Moderate Risk'
            : 'Elevated Risk';
    final riskColor = totalHighRisk == 0
        ? const Color(0xFF10B981)
        : totalHighRisk <= 3
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('14-Day Risk Trend',
                    style: AppTextStyles.displayMedium),
                const SizedBox(width: 6),
                const Icon(Icons.cloud_outlined,
                    size: 14, color: AppColors.accentBlue),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: riskColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                riskLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: riskColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: AppDecorations.glassmorphismCard(),
          child: SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          'Day ${spot.x.toInt() + 1}: ${spot.y.toInt()} high-risk events',
                          AppTextStyles.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: riskByDay,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
                    ),
                    isCurved: true,
                    preventCurveOverShooting: true,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: riskByDay.length <= 14,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3,
                        color: const Color(0xFFF59E0B),
                        strokeColor: Colors.white,
                        strokeWidth: 1.5,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFF59E0B).withValues(alpha: 0.22),
                          const Color(0xFFF59E0B).withValues(alpha: 0.01),
                        ],
                      ),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      const FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble() || value == meta.max) return const SizedBox();
                        return Text(
                          value.toInt().toString(),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      getTitlesWidget: (value, meta) => Text(
                        'D${value.toInt() + 1}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
