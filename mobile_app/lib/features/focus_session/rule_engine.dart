import 'dart:math';

import 'focus_detection_engine.dart';

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
    const base = 100.0;

    final countPenalty = totalDistractions > 0
        ? 15 * log(totalDistractions + 1) / log(2)
        : 0.0;

    final recoveryPenalty = (avgRecoverySeconds / 60).clamp(0, 20) * 1.0;
    final criticalPenalty = criticalDistractions * 10.0;
    final bonus = (sessionMinutes / 10).floor() * 2.0;

    return (base - countPenalty - recoveryPenalty - criticalPenalty + bonus)
        .clamp(0.0, 100.0);
  }
}
