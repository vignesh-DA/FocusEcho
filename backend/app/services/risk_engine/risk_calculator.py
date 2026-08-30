from __future__ import annotations

import math
from dataclasses import asdict
from typing import Iterable

from .feature_extractor import RiskFeatures, extract_risk_features


class RiskCalculator:
    """Deterministic, explainable risk predictor.

    This intentionally remains a weighted scorer until enough labelled user
    outcomes exist to evaluate a statistical model responsibly.
    """

    def calculate(self, events: Iterable[dict], current_event: dict | None = None) -> dict:
        features = extract_risk_features(events, current_event)
        score = 0.0
        reasons: list[str] = []

        category_weight = {
            "always_distraction": 35,
            "allowed_with_limit": 12,
            "always_allowed": 0,
            "neutral": 0,
            "unknown": 15,
        }.get(features.category, 15)
        score += category_weight
        if category_weight >= 30:
            reasons.append("This app is configured as distracting")

        away_score = min(24.0, math.log1p(features.time_away_seconds) / math.log(61) * 24)
        score += away_score
        if features.time_away_seconds >= 60:
            reasons.append("Long distraction duration")

        frequency_score = min(20.0, features.distractions_last_30_minutes * 4.0)
        score += frequency_score
        if features.distractions_last_30_minutes >= 3:
            reasons.append("Frequent recent distractions")

        repeat_score = min(14.0, features.repeated_same_app * 7.0)
        score += repeat_score
        if features.repeated_same_app >= 1:
            reasons.append("Repeated distraction from the same app")

        if features.recovery_rate is not None and features.recovery_rate < 0.5:
            score += 7.0
            reasons.append("Low recent recovery rate")
        if features.session_minutes >= 45:
            score += 3.0

        score = round(max(0.0, min(100.0, score)), 1)
        confidence = min(0.9, 0.45 + min(features.distractions_last_30_minutes, 6) * 0.05)
        if not reasons:
            reasons.append("No elevated distraction pattern detected")
        return {
            "risk_score": score,
            "risk_level": self.risk_level(score),
            "confidence": round(confidence, 2),
            "reasons": reasons,
            "features": asdict(features),
        }

    @staticmethod
    def risk_level(score: float) -> str:
        if score < 20:
            return "LOW"
        if score < 45:
            return "MEDIUM"
        if score < 70:
            return "HIGH"
        return "CRITICAL"
