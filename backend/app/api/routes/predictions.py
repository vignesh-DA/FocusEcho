from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Body

from ...services.risk_engine import RiskCalculator

router = APIRouter(prefix="/api/v1/predictions", tags=["predictions"])
_calculator = RiskCalculator()


@router.post("/distraction-risk")
def distraction_risk(
    events: list[dict[str, Any]] = Body(
        default=[],
        description="Minimal distraction-event metadata. Raw notification or message content is never accepted.",
    ),
) -> dict[str, Any]:
    """Return an explainable estimate, never a certainty claim.

    A user-scoped GET endpoint will be added with authenticated analytics
    retrieval once the API auth boundary is introduced.  Keeping this endpoint
    payload-only prevents accidental cross-user data reads in the interim.
    """
    if not events:
        return {
            "probability": None,
            "risk_level": "UNKNOWN",
            "recommended_action": "COLLECT_MORE_DATA",
            "confidence": 0.0,
            "reasons": ["Not enough data yet to make a distraction-risk prediction."],
        }
    result = _calculator.calculate(events)
    return {
        "probability": round(result["risk_score"] / 100, 2),
        "risk_level": result["risk_level"],
        "recommended_action": _recommended_action(result["risk_level"]),
        "confidence": result["confidence"],
        "reasons": result["reasons"],
    }


def _recommended_action(risk_level: str) -> str:
    return {
        "LOW": "CONTINUE",
        "MEDIUM": "GENTLE_NUDGE",
        "HIGH": "SHORT_BREAK",
        "CRITICAL": "RESTART_SHORTER_SESSION",
    }[risk_level]
