from __future__ import annotations

from datetime import datetime, timedelta, timezone
import math
from typing import List


class RuleEngine:
    @staticmethod
    def compute_risk(events: List[dict], current_package: str) -> str:
        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(minutes=30)
        recent_events = [
            event
            for event in events
            if datetime.fromisoformat(str(event["triggered_at"]).replace("Z", "+00:00")) >= cutoff
            and event.get("event_type", "distraction") == "distraction"
        ]
        if not events:
            return "SAFE"

        latest = sorted(events, key=lambda event: str(event["triggered_at"]))[-1]
        category = str(latest.get("app_category") or "unknown")
        time_away_seconds = int(latest.get("time_away_seconds") or 0)
        returned_to_focus = bool(latest.get("returned_to_origin"))

        score = RuleEngine.compute_risk_score(
            category=category,
            time_away_seconds=time_away_seconds,
            distractions_in_last_30_min=len(recent_events),
            returned_to_focus=returned_to_focus,
        )
        return RuleEngine.risk_label(score)

    @staticmethod
    def compute_risk_score(
        *,
        category: str,
        time_away_seconds: int,
        distractions_in_last_30_min: int,
        returned_to_focus: bool,
    ) -> float:
        score = 0.0
        category_weight = {
            "always_distraction": 60,
            "allowed_with_limit": 20,
            "always_allowed": 0,
            "neutral": 0,
            "unknown": 30,
        }.get(category, 30)
        score += category_weight

        if time_away_seconds > 0:
            score += (math.log(time_away_seconds + 1) / math.log(60)) * 25

        score += distractions_in_last_30_min * 5

        if returned_to_focus and time_away_seconds < 30:
            score -= 15

        return max(0.0, min(100.0, score))

    @staticmethod
    def risk_label(score: float) -> str:
        if score < 20:
            return "LOW"
        if score < 45:
            return "MEDIUM"
        if score < 70:
            return "HIGH"
        return "CRITICAL"

    @staticmethod
    def compute_focus_score(
        total_distractions: int,
        session_minutes: int,
        avg_recovery_seconds: float,
        critical_distractions: int,
    ) -> float:
        base = 100.0
        count_penalty = 15 * math.log(total_distractions + 1, 2) if total_distractions > 0 else 0.0
        recovery_penalty = min(20.0, avg_recovery_seconds / 60)
        critical_penalty = critical_distractions * 10.0
        bonus = (session_minutes // 10) * 2.0
        return max(0.0, min(100.0, base - count_penalty - recovery_penalty - critical_penalty + bonus))

    @staticmethod
    def get_risk_label_color(risk: str) -> str:
        return {
            "CRITICAL": "#FF4444",
            "HIGH": "#FF8C00",
            "MEDIUM": "#FFD700",
            "LOW": "#00FF88",
            "SAFE": "#00C2FF",
        }.get(risk, "#8B9CB6")
