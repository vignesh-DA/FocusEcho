from typing import Annotated, Any

from fastapi import APIRouter, Body, Depends

from ..auth import require_auth
from ...services.scoring_service import ScoringService

router = APIRouter(prefix="/api/v1/scoring", tags=["scoring"])
service = ScoringService()


@router.post("/session/{session_id}")
def score(
    session_id: str,
    authed_user: Annotated[str, Depends(require_auth)],
    events: list[dict[str, Any]] = Body(
        ...,
        description="List of distraction events used to compute session score.",
        example=[
            {
                "package_name": "instagram",
                "triggered_at": "2026-04-16T10:00:00Z",
                "recovery_time_seconds": 12,
                "risk_score": "MEDIUM",
            },
            {
                "package_name": "instagram",
                "triggered_at": "2026-04-16T10:05:00Z",
                "recovery_time_seconds": 8,
                "risk_score": "LOW",
            },
        ],
    ),
) -> dict[str, Any]:
    # authed_user is available if the scoring result needs to be stored per-user in future.
    return service.score_session(session_id, events)
