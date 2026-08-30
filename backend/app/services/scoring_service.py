from __future__ import annotations

from typing import Dict, List

from .rule_engine import RuleEngine
from .scoring.focus_score import explain_focus_score


class ScoringService:
    def __init__(self, rule_engine: RuleEngine | None = None) -> None:
        self.rule_engine = rule_engine or RuleEngine()

    def score_session(self, session_id: str, events: List[dict]) -> Dict[str, object]:
        distraction_events = [
            event for event in events if event.get("event_type", "distraction") == "distraction"
        ]
        total_distractions = len(distraction_events)
        risk_score = self.rule_engine.compute_risk(events, events[-1]["package_name"] if events else "")
        # Session minutes are optional in legacy clients.  Preserve the old
        # fallback while returning an explainable, deterministic breakdown.
        session_minutes = max(1, int(events[-1].get("session_minutes", len(events) * 2))) if events else 1
        score_details = explain_focus_score(events, session_minutes)
        return {
            "session_id": session_id,
            "focus_score": score_details["score"],
            "score_breakdown": score_details,
            "risk_score": risk_score,
            "total_distractions": total_distractions,
            "recovery_rate": round(
                sum(1 for event in distraction_events if event.get("is_recovered")) / total_distractions,
                2,
            ) if total_distractions else 1.0,
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
