import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'focus_session_state.dart';
import 'widgets/coach_debrief_card.dart';

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({
    super.key,
    required this.summary,
    required this.stats,
    required this.onDismiss,
  });

  final SessionSummary summary;
  final Map<String, dynamic>? stats;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final snapshot = _feedSnapshot;
    final bars = _distractionsPerBlock(snapshot);
    final median = (stats?['median_recovery_seconds'] as num?)?.toInt() ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Session Complete')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: AppDecorations.glassmorphismCard(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            size: 56, color: AppColors.accentYellow),
                        const SizedBox(height: 12),
                        Text('Session Complete',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.displayLarge
                                .copyWith(fontSize: 26)),
                        const SizedBox(height: 16),
                        if (summary.intent.trim().isNotEmpty) ...[
                          Text('Your intent', style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 4),
                          Text(
                            '"${summary.intent}"',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.accentBlue,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.card.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _detailRow(
                                  'Planned focus', summary.productiveApp),
                              const SizedBox(height: 6),
                              _detailRow('Duration',
                                  _formatDuration(summary.actualSeconds)),
                              const SizedBox(height: 6),
                              _detailRow('Median recovery', '${median}s'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _summaryStat('${summary.totalDistractions}',
                                'Distractions', AppColors.accentRed),
                            _summaryStat('${summary.sessionXp}', 'XP',
                                AppColors.accentYellow),
                            _summaryStat(summary.focusScore.toStringAsFixed(0),
                                'Focus Score', AppColors.accentGreen),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Median recovery: ${median}s',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.accentGreen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    decoration: AppDecorations.glassmorphismCard(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Distractions by 15-minute block',
                            style: AppTextStyles.bodyLarge),
                        const SizedBox(height: 4),
                        Text(
                            'Each bar represents one quarter-hour of this session.',
                            style: AppTextStyles.bodyMedium
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 230,
                          child: Semantics(
                            label: _chartSemantics(bars),
                            child: BarChart(
                              _chartData(bars),
                              swapAnimationDuration: Duration.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CoachDebriefCard(sessionId: summary.sessionId),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: onDismiss,
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _feedSnapshot {
    final raw = stats?['feed_snapshot'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((row) {
      return Map<String, dynamic>.from(row);
    }).toList(growable: false);
  }

  List<int> _distractionsPerBlock(List<Map<String, dynamic>> rows) {
    final duration =
        (stats?['duration_seconds'] as num?)?.toInt() ?? summary.actualSeconds;
    final blockCount = math.max(1, (math.max(duration, 1) + 899) ~/ 900);
    final counts = List<int>.filled(blockCount, 0);
    final startedAt = DateTime.tryParse(stats?['started_at']?.toString() ?? '');

    for (final row in rows) {
      final eventType = row['event_type']?.toString();
      if (eventType == 'intentional') continue;
      final timestamp =
          DateTime.tryParse(row['triggered_at']?.toString() ?? '');
      final minuteFromSession = row['session_minute'] as num?;
      final offsetSeconds = timestamp != null && startedAt != null
          ? timestamp.difference(startedAt).inSeconds
          : (minuteFromSession?.toInt() ?? 0) * 60;
      if (offsetSeconds < 0) continue;
      final block = math.min(blockCount - 1, offsetSeconds ~/ 900);
      counts[block]++;
    }
    return counts;
  }

  BarChartData _chartData(List<int> bars) {
    final maxCount = bars.fold<int>(0, math.max);
    return BarChartData(
      minY: 0,
      maxY: math.max(1, maxCount + 1).toDouble(),
      alignment: BarChartAlignment.spaceAround,
      barTouchData: BarTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 1,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.textSecondary.withValues(alpha: 0.15),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            getTitlesWidget: (value, meta) => Text(
              '${value.toInt() * 15}m',
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 10),
            ),
          ),
        ),
      ),
      barGroups: [
        for (var index = 0; index < bars.length; index++)
          BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: bars[index].toDouble(),
                color: AppColors.accentBlue,
                width: 18,
                borderRadius: BorderRadius.zero,
              ),
            ],
          ),
      ],
    );
  }

  String _chartSemantics(List<int> bars) {
    if (bars.every((value) => value == 0)) {
      return 'Distractions by 15-minute block. No distractions recorded.';
    }
    return 'Distractions by 15-minute block: ${bars.asMap().entries.map((entry) => '${entry.key * 15} minutes, ${entry.value}').join('; ')}.';
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right, style: AppTextStyles.bodyLarge),
        ),
      ],
    );
  }

  Widget _summaryStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.displayMedium.copyWith(color: color)),
        Text(label, style: AppTextStyles.bodyMedium),
      ],
    );
  }

  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    return '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
