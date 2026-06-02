from __future__ import annotations

from typing import Dict, List

from .rule_engine import RuleEngine


class ScoringService:
    def __init__(self, rule_engine: RuleEngine | None = None) -> None:
        self.rule_engine = rule_engine or RuleEngine()

    def score_session(self, session_id: str, events: List[dict]) -> Dict[str, object]:
        distraction_events = [
            event for event in events if event.get("event_type", "distraction") == "distraction"
        ]
        total_distractions = len(distraction_events)
        total_recovered = sum(1 for event in distraction_events if event.get("is_recovered"))
        recovery_rate = (total_recovered / total_distractions) if total_distractions else 1.0
        risk_score = self.rule_engine.compute_risk(events, events[-1]["package_name"] if events else "")
        avg_recovery_seconds = (
            sum((event.get("recovery_time_seconds") or 0) for event in distraction_events)
            / total_distractions
            if total_distractions
            else 0.0
        )
        critical_distractions = sum(
            1 for event in distraction_events if event.get("risk_score") == "CRITICAL"
        )
        focus_score = self.rule_engine.compute_focus_score(
            total_distractions,
            max(1, len(events) * 2),
            avg_recovery_seconds,
            critical_distractions,
        )
        return {
            "session_id": session_id,
            "focus_score": focus_score,
            "risk_score": risk_score,
            "total_distractions": total_distractions,
            "recovery_rate": round(recovery_rate, 2),
            "recommendation": self.get_recommendation(risk_score),
        }

    def get_recommendation(self, risk_score: str) -> str:
        recommendations = {
            "CRITICAL": "Take a short reset, remove distractions, and restart with one clear objective.",
            "HIGH": "Use stricter reminders and keep only one productive app open for this session.",
            "MEDIUM": "Good effort—recover faster by returning within 10 seconds when nudged.",
            "LOW": "Nice control. Keep this pace and extend your next session by 10 minutes.",
            "SAFE": "Excellent focus. Maintain your routine and build your streak.",
        }
        return recommendations.get(risk_score, recommendations["SAFE"])
