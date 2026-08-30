import 'package:flutter_test/flutter_test.dart';

import 'package:focus_echo_ai/features/focus_session/focus_detection_engine.dart';
import 'package:focus_echo_ai/features/focus_session/rule_engine.dart';

void main() {
  group('RuleEngine.computeRiskScore', () {
    test('scores higher for distractions with long time away', () {
      final shortScore = RuleEngine.computeRiskScore(
        category: AppCategory.allowedWithLimit,
        timeAwaySeconds: 5,
        distractionsInLast30Min: 0,
        returnedToFocus: true,
      );
      final longScore = RuleEngine.computeRiskScore(
        category: AppCategory.allowedWithLimit,
        timeAwaySeconds: 120,
        distractionsInLast30Min: 0,
        returnedToFocus: false,
      );
      expect(longScore, greaterThan(shortScore));
    });

    test('risk label buckets correctly', () {
      expect(RuleEngine.riskLabel(5), 'LOW');
      expect(RuleEngine.riskLabel(30), 'MEDIUM');
      expect(RuleEngine.riskLabel(60), 'HIGH');
      expect(RuleEngine.riskLabel(90), 'CRITICAL');
    });
  });

  group('RuleEngine.computeFocusScore', () {
    test('returns 100 for no distractions in short session', () {
      final score = RuleEngine.computeFocusScore(
        totalDistractions: 0,
        sessionMinutes: 5,
        avgRecoverySeconds: 0,
        criticalDistractions: 0,
      );
      expect(score, 100.0);
    });

    test('penalizes critical distractions and slow recovery', () {
      final score = RuleEngine.computeFocusScore(
        totalDistractions: 3,
        sessionMinutes: 30,
        avgRecoverySeconds: 120,
        criticalDistractions: 2,
      );
      expect(score, lessThan(80.0));
    });

    test('clamps within 0-100 range', () {
      final score = RuleEngine.computeFocusScore(
        totalDistractions: 20,
        sessionMinutes: 5,
        avgRecoverySeconds: 600,
        criticalDistractions: 5,
      );
      expect(score, 0.0);
    });
  });

  group('RuleEngine.explainFocusScore', () {
    test('returns deterministic factors that add up to the score', () {
      final breakdown = RuleEngine.explainFocusScore(
        totalDistractions: 2,
        sessionMinutes: 30,
        avgRecoverySeconds: 15,
        criticalDistractions: 0,
      );

      expect(
        breakdown.focusDuration +
            breakdown.distractionControl +
            breakdown.recovery +
            breakdown.consistency,
        breakdown.score,
      );
      expect(breakdown.negativeFactors, contains('2 distractions'));
    });
  });
}
