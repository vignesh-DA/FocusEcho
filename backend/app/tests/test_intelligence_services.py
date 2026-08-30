from datetime import datetime, timezone
import unittest

from app.services.risk_engine import RiskCalculator
from app.services.scoring.focus_score import explain_focus_score


class RiskCalculatorTests(unittest.TestCase):
    def test_repeated_long_distraction_is_high_risk(self):
        now = datetime.now(timezone.utc).isoformat()
        events = [
            {
                "package_name": "com.instagram.android",
                "triggered_at": now,
                "app_category": "always_distraction",
                "time_away_seconds": 180,
                "is_recovered": False,
            }
            for _ in range(3)
        ]
        result = RiskCalculator().calculate(events)
        self.assertIn(result["risk_level"], {"HIGH", "CRITICAL"})
        self.assertIn("Repeated distraction from the same app", result["reasons"])

    def test_empty_history_does_not_claim_a_pattern(self):
        result = RiskCalculator().calculate([])
        self.assertEqual(result["risk_level"], "LOW")
        self.assertEqual(result["reasons"], ["No elevated distraction pattern detected"])


class FocusScoreTests(unittest.TestCase):
    def test_breakdown_is_explainable_and_bounded(self):
        result = explain_focus_score([], 30)
        self.assertEqual(result["score"], 100.0)
        self.assertIn("Maintained a distraction-free session", result["positive_factors"])
        self.assertEqual(sum(result["breakdown"].values()), result["score"])


if __name__ == "__main__":
    unittest.main()
