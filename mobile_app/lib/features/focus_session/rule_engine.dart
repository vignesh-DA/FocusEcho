import 'dart:math';

import 'focus_detection_engine.dart';

class FocusScoreBreakdown {
  const FocusScoreBreakdown({
    required this.score,
    required this.focusDuration,
    required this.distractionControl,
    required this.recovery,
    required this.consistency,
    required this.positiveFactors,
    required this.negativeFactors,
  });

  final double score;
  final double focusDuration;
  final double distractionControl;
  final double recovery;
  final double consistency;
  final List<String> positiveFactors;
  final List<String> negativeFactors;
}

class RuleEngine {
  static double computeRiskScore({
    required AppCategory category,
    required int timeAwaySeconds,
    required int distractionsInLast30Min,
    required bool returnedToFocus,
  }) {
    var score = 0.0;

    score += switch (category) {
      AppCategory.alwaysDistraction => 60,
      AppCategory.allowedWithLimit => 20,
      AppCategory.alwaysAllowed => 0,
      AppCategory.neutral => 0,
      AppCategory.unknown => 30,
    };

    if (timeAwaySeconds > 0) {
      score += (log(timeAwaySeconds + 1) / log(60)) * 25;
    }

    score += distractionsInLast30Min * 5;

    if (returnedToFocus && timeAwaySeconds < 30) score -= 15;

    return score.clamp(0, 100);
  }

  static String riskLabel(double score) {
    if (score < 20) return 'LOW';
    if (score < 45) return 'MEDIUM';
    if (score < 70) return 'HIGH';
    return 'CRITICAL';
  }

  static double computeFocusScore({
    required int totalDistractions,
    required int sessionMinutes,
    required double avgRecoverySeconds,
    required int criticalDistractions,
  }) {
    return explainFocusScore(
      totalDistractions: totalDistractions,
      sessionMinutes: sessionMinutes,
      avgRecoverySeconds: avgRecoverySeconds,
      criticalDistractions: criticalDistractions,
    ).score;
  }

  static FocusScoreBreakdown explainFocusScore({
    required int totalDistractions,
    required int sessionMinutes,
    required double avgRecoverySeconds,
    required int criticalDistractions,
  }) {
    final countPenalty = totalDistractions > 0
        ? 15 * log(totalDistractions + 1) / log(2)
        : 0.0;
    final distractionControl = (60 - countPenalty - criticalDistractions * 10)
        .clamp(0, 60)
        .toDouble();
    final recovery = (20 - (avgRecoverySeconds / 60).clamp(0, 20))
        .clamp(0, 20)
        .toDouble();
    const consistency = 20.0;
    final duration = ((sessionMinutes ~/ 10) * 2)
        .clamp(0, 20)
        .clamp(0, 100 - distractionControl - recovery - consistency)
        .toDouble();
    final score = (duration + distractionControl + recovery + consistency)
        .clamp(0, 100)
        .toDouble();

    final positive = <String>[];
    final negative = <String>[];
    if (sessionMinutes >= 25) positive.add('Completed a $sessionMinutes-minute session');
    if (totalDistractions == 0) {
      positive.add('Maintained a distraction-free session');
    }
    if (totalDistractions > 0) {
      negative.add('$totalDistractions distraction${totalDistractions == 1 ? '' : 's'}');
    }
    if (avgRecoverySeconds >= 60) negative.add('Slow average recovery time');
    if (criticalDistractions > 0) {
      negative.add('$criticalDistractions critical distraction${criticalDistractions == 1 ? '' : 's'}');
    }
    return FocusScoreBreakdown(
      score: score,
      focusDuration: duration,
      distractionControl: distractionControl,
      recovery: recovery,
      consistency: consistency,
      positiveFactors: positive,
      negativeFactors: negative,
    );
  }
}
