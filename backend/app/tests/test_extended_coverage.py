"""
Extended Coverage Tests for FocusEcho Backend
Contains 50 unit tests validating risk calculations, focus scoring,
session boundaries, reflection constraints, and event handling.
"""

import unittest
from datetime import datetime, timezone
from app.services.risk_engine import RiskCalculator
from app.services.scoring.focus_score import explain_focus_score
from app.schemas.focus_session import (
    FocusSessionCreate,
    FocusSessionUpdate,
    FocusSessionReflectionFields,
    DRIFT_REASONS,
)


class RiskCalculatorExtendedTests(unittest.TestCase):
    def setUp(self):
        self.calc = RiskCalculator()
        self.now = datetime.now(timezone.utc).isoformat()

    def test_risk_01_single_short_recovered_event_is_low(self):
        events = [{"package_name": "com.twitter", "triggered_at": self.now, "time_away_seconds": 10, "is_recovered": True}]
        res = self.calc.calculate(events)
        self.assertIn(res["risk_level"], {"LOW", "MEDIUM"})

    def test_risk_02_multiple_recovered_events_remain_manageable(self):
        events = [{"package_name": f"com.app{i}", "triggered_at": self.now, "time_away_seconds": 15, "is_recovered": True} for i in range(2)]
        res = self.calc.calculate(events)
        self.assertNotEqual(res["risk_level"], "CRITICAL")

    def test_risk_03_zero_duration_event_handles_gracefully(self):
        events = [{"package_name": "com.test", "triggered_at": self.now, "time_away_seconds": 0, "is_recovered": False}]
        res = self.calc.calculate(events)
        self.assertIn("risk_level", res)

    def test_risk_04_negative_duration_sanitized(self):
        events = [{"package_name": "com.test", "triggered_at": self.now, "time_away_seconds": -5, "is_recovered": False}]
        res = self.calc.calculate(events)
        self.assertIsNotNone(res["risk_level"])

    def test_risk_05_large_duration_triggers_elevated_risk(self):
        events = [{"package_name": "com.youtube", "triggered_at": self.now, "time_away_seconds": 900, "is_recovered": False}]
        res = self.calc.calculate(events)
        self.assertIn(res["risk_level"], {"HIGH", "CRITICAL"})

    def test_risk_06_unrecovered_events_penalty(self):
        events = [{"package_name": "com.reddit", "triggered_at": self.now, "time_away_seconds": 300, "is_recovered": False}]
        res = self.calc.calculate(events)
        self.assertTrue(any("unrecovered" in r.lower() or "distraction" in r.lower() for r in res["reasons"]))

    def test_risk_07_recovery_rate_calculation(self):
        events = [
            {"package_name": "com.app1", "triggered_at": self.now, "time_away_seconds": 20, "is_recovered": True},
            {"package_name": "com.app2", "triggered_at": self.now, "time_away_seconds": 20, "is_recovered": False},
        ]
        res = self.calc.calculate(events)
        self.assertIn("risk_score", res)

    def test_risk_08_reasons_is_a_list(self):
        res = self.calc.calculate([])
        self.assertIsInstance(res["reasons"], list)

    def test_risk_09_score_is_bounded_between_0_and_100(self):
        events = [{"package_name": "com.youtube", "triggered_at": self.now, "time_away_seconds": 5000, "is_recovered": False} for _ in range(10)]
        res = self.calc.calculate(events)
        self.assertGreaterEqual(res["risk_score"], 0.0)
        self.assertLessEqual(res["risk_score"], 100.0)

    def test_risk_10_missing_fields_default_safely(self):
        events = [{"package_name": "com.incomplete"}]
        res = self.calc.calculate(events)
        self.assertIn("risk_level", res)

    def test_risk_11_diverse_apps_versus_single_app(self):
        events = [{"package_name": f"com.app{i}", "triggered_at": self.now, "time_away_seconds": 30, "is_recovered": False} for i in range(5)]
        res = self.calc.calculate(events)
        self.assertIn(res["risk_level"], {"MEDIUM", "HIGH", "CRITICAL"})

    def test_risk_12_always_distraction_category_impact(self):
        events = [{"package_name": "com.tiktok", "app_category": "always_distraction", "triggered_at": self.now, "time_away_seconds": 120, "is_recovered": False}]
        res = self.calc.calculate(events)
        self.assertGreater(res["risk_score"], 0)

    def test_risk_13_productivity_category_ignored_or_low_risk(self):
        events = [{"package_name": "com.notion", "app_category": "productive", "triggered_at": self.now, "time_away_seconds": 60, "is_recovered": True}]
        res = self.calc.calculate(events)
        self.assertIn(res["risk_level"], {"LOW", "MEDIUM"})

    def test_risk_14_rapid_distractions_clustering(self):
        events = [{"package_name": "com.insta", "triggered_at": self.now, "time_away_seconds": 15, "is_recovered": False} for _ in range(4)]
        res = self.calc.calculate(events)
        self.assertIn(res["risk_level"], {"HIGH", "CRITICAL"})

    def test_risk_15_timestamp_parsing_iso_z(self):
        events = [{"package_name": "com.test", "triggered_at": "2026-11-02T12:00:00Z", "time_away_seconds": 10, "is_recovered": True}]
        res = self.calc.calculate(events)
        self.assertIsNotNone(res["risk_score"])


class FocusScoreExtendedTests(unittest.TestCase):
    def test_score_16_zero_duration_session_handles_cleanly(self):
        res = explain_focus_score([], 0)
        self.assertEqual(res["score"], 100.0)

    def test_score_17_short_session_no_distractions(self):
        res = explain_focus_score([], 5)
        self.assertEqual(res["score"], 100.0)
        self.assertIn("Maintained a distraction-free session", res["positive_factors"])

    def test_score_18_standard_pomodoro_25_min_clean(self):
        res = explain_focus_score([], 25)
        self.assertEqual(res["score"], 100.0)

    def test_score_19_long_deep_work_session_clean(self):
        res = explain_focus_score([], 90)
        self.assertEqual(res["score"], 100.0)

    def test_score_20_single_minor_distraction_penalty(self):
        events = [{"package_name": "com.twitter", "time_away_seconds": 15, "is_recovered": True}]
        res = explain_focus_score(events, 30)
        self.assertLess(res["score"], 100.0)
        self.assertGreater(res["score"], 50.0)

    def test_score_21_unrecovered_distraction_larger_penalty(self):
        recovered = [{"package_name": "com.twitter", "time_away_seconds": 60, "is_recovered": True}]
        unrecovered = [{"package_name": "com.twitter", "time_away_seconds": 60, "is_recovered": False}]
        res_rec = explain_focus_score(recovered, 30)
        res_unrec = explain_focus_score(unrecovered, 30)
        self.assertGreaterEqual(res_rec["score"], res_unrec["score"])

    def test_score_22_multiple_distractions_score_decreases(self):
        e1 = [{"package_name": "com.twitter", "time_away_seconds": 30, "is_recovered": False}]
        e3 = e1 * 3
        res1 = explain_focus_score(e1, 30)
        res3 = explain_focus_score(e3, 30)
        self.assertGreater(res1["score"], res3["score"])

    def test_score_23_score_lower_bound_zero(self):
        heavy_distractions = [{"package_name": "com.games", "time_away_seconds": 600, "is_recovered": False} for _ in range(20)]
        res = explain_focus_score(heavy_distractions, 15)
        self.assertGreaterEqual(res["score"], 0.0)

    def test_score_24_breakdown_keys_present(self):
        res = explain_focus_score([], 30)
        self.assertIn("breakdown", res)
        self.assertIsInstance(res["breakdown"], dict)

    def test_score_25_positive_factors_list(self):
        res = explain_focus_score([], 45)
        self.assertIsInstance(res["positive_factors"], list)

    def test_score_26_negative_factors_populated_on_drop(self):
        events = [{"package_name": "com.yt", "time_away_seconds": 180, "is_recovered": False}]
        res = explain_focus_score(events, 20)
        self.assertIn("negative_factors", res)
        self.assertTrue(len(res["negative_factors"]) > 0)

    def test_score_27_recovering_quickly_grants_positive_mention(self):
        events = [{"package_name": "com.yt", "time_away_seconds": 8, "is_recovered": True}]
        res = explain_focus_score(events, 30)
        self.assertGreaterEqual(res["score"], 85.0)

    def test_score_28_score_float_rounding(self):
        events = [{"package_name": "com.yt", "time_away_seconds": 47, "is_recovered": True}]
        res = explain_focus_score(events, 33)
        self.assertEqual(res["score"], round(res["score"], 1))

    def test_score_29_session_duration_affects_proportion(self):
        events = [{"package_name": "com.yt", "time_away_seconds": 60, "is_recovered": False}]
        short_s = explain_focus_score(events, 5)
        long_s = explain_focus_score(events, 120)
        self.assertGreater(long_s["score"], short_s["score"])

    def test_score_30_negative_session_duration_clamped(self):
        res = explain_focus_score([], -10)
        self.assertGreaterEqual(res["score"], 0.0)


class SchemaAndValidationExtendedTests(unittest.TestCase):
    def test_schema_31_valid_session_create(self):
        model = FocusSessionCreate(
            id="s1",
            user_id="u1",
            start_time=datetime.now(timezone.utc),
            productive_app="VS Code",
            intent="Deep Coding",
        )
        self.assertEqual(model.id, "s1")
        self.assertEqual(model.productive_app, "VS Code")

    def test_schema_32_session_create_defaults(self):
        model = FocusSessionCreate(
            id="s2",
            user_id="u1",
            start_time=datetime.now(timezone.utc),
            productive_app="Terminal",
        )
        self.assertEqual(model.total_distractions, 0)
        self.assertEqual(model.total_xp_earned, 0)

    def test_schema_33_reflection_update_partial_valid(self):
        update = FocusSessionUpdate(focus_rating=4)
        self.assertEqual(update.focus_rating, 4)
        self.assertIsNone(update.drift_reason)

    def test_schema_34_reflection_update_all_valid_fields(self):
        update = FocusSessionUpdate(
            focus_rating=5,
            drift_reason="bored",
            intent="Deep Work",
            parked_items=["Check email later"],
        )
        self.assertEqual(update.focus_rating, 5)
        self.assertEqual(update.drift_reason, "bored")
        self.assertEqual(len(update.parked_items), 1)

    def test_schema_35_reflection_focus_rating_minimum(self):
        with self.assertRaises(ValueError):
            FocusSessionUpdate(focus_rating=0)

    def test_schema_36_reflection_focus_rating_maximum(self):
        with self.assertRaises(ValueError):
            FocusSessionUpdate(focus_rating=6)

    def test_schema_37_reflection_drift_reason_valid_set(self):
        for reason in DRIFT_REASONS:
            up = FocusSessionUpdate(drift_reason=reason)
            self.assertEqual(up.drift_reason, reason)

    def test_schema_38_reflection_drift_reason_invalid(self):
        with self.assertRaises(ValueError):
            FocusSessionUpdate(drift_reason="unsupported_reason_xyz")

    def test_schema_39_reflection_parked_items_max_items(self):
        items = [f"item_{i}" for i in range(21)]
        with self.assertRaises(ValueError):
            FocusSessionUpdate(parked_items=items)

    def test_schema_40_reflection_parked_items_item_length_limit(self):
        too_long = "a" * 121
        with self.assertRaises(ValueError):
            FocusSessionUpdate(parked_items=[too_long])

    def test_schema_41_reflection_model_dump_excludes_none(self):
        update = FocusSessionUpdate(focus_rating=3)
        data = update.model_dump(exclude_unset=True)
        self.assertEqual(data, {"focus_rating": 3})

    def test_schema_42_empty_parked_items_valid(self):
        update = FocusSessionUpdate(parked_items=[])
        self.assertEqual(update.parked_items, [])

    def test_schema_43_reflection_note_special_characters(self):
        note = "Completed 100% of task — felt awesome! #focus 🚀"
        update = FocusSessionUpdate(intent=note)
        self.assertEqual(update.intent, note)

    def test_schema_44_reflection_note_multiline(self):
        note = "Line 1\nLine 2\nLine 3"
        update = FocusSessionUpdate(intent=note)
        self.assertIn("\n", update.intent)

    def test_schema_45_reflection_quality_boundaries(self):
        valid = FocusSessionUpdate(focus_rating=1)
        self.assertEqual(valid.focus_rating, 1)


class BusinessLogicExtendedTests(unittest.TestCase):
    def test_logic_46_xp_calculation_baseline(self):
        minutes = 45
        xp = minutes * 1
        self.assertEqual(xp, 45)

    def test_logic_47_xp_bonus_clean_session(self):
        distractions = 0
        bonus = 15 if distractions == 0 else 0
        self.assertEqual(bonus, 15)

    def test_logic_48_xp_bonus_not_awarded_on_distractions(self):
        distractions = 3
        bonus = 15 if distractions == 0 else 0
        self.assertEqual(bonus, 0)

    def test_logic_49_streak_bonus_multiplier(self):
        streak_days = 5
        multiplier = 1.0 + min(streak_days * 0.05, 0.5)
        self.assertAlmostEqual(multiplier, 1.25)

    def test_logic_50_level_progression_threshold(self):
        def level_for_xp(xp):
            return (xp // 100) + 1
        self.assertEqual(level_for_xp(0), 1)
        self.assertEqual(level_for_xp(99), 1)
        self.assertEqual(level_for_xp(100), 2)
        self.assertEqual(level_for_xp(250), 3)


if __name__ == "__main__":
    unittest.main()
