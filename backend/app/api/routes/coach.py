from __future__ import annotations

from typing import Annotated, Any, Dict
from fastapi import APIRouter, Depends, HTTPException, status

from ..auth import require_auth
from ...schemas.coach import (
    CoachFeedbackRequest,
    CoachOptInRequest,
    CoachOptInResponse,
    IntentionRefineRequest,
    IntentionRefineResponse,
    SessionDebriefRequest,
    SessionDebriefResponse,
)
from ...services.ai_coach_service import AiCoachService

router = APIRouter(prefix="/api/v1/coach", tags=["AI Coach"])


def _service() -> AiCoachService:
    return AiCoachService()


@router.get("/opt-in", response_model=CoachOptInResponse)
def get_coach_opt_in(
    authed_user: Annotated[str, Depends(require_auth)],
    service: Annotated[AiCoachService, Depends(_service)],
) -> CoachOptInResponse:
    """Check whether the user has opted into EchoCoach."""
    is_opted_in, opted_in_at = service.get_opt_in_status(authed_user)
    return CoachOptInResponse(is_opted_in=is_opted_in, opted_in_at=opted_in_at)


@router.post("/opt-in", response_model=CoachOptInResponse)
def set_coach_opt_in(
    payload: CoachOptInRequest,
    authed_user: Annotated[str, Depends(require_auth)],
    service: Annotated[AiCoachService, Depends(_service)],
) -> CoachOptInResponse:
    """Update user's opt-in consent for EchoCoach."""
    is_opted_in, opted_in_at = service.set_opt_in_status(authed_user, payload.opt_in)
    return CoachOptInResponse(is_opted_in=is_opted_in, opted_in_at=opted_in_at)


@router.post("/refine-intention", response_model=IntentionRefineResponse)
def refine_intention(
    payload: IntentionRefineRequest,
    authed_user: Annotated[str, Depends(require_auth)],
    service: Annotated[AiCoachService, Depends(_service)],
) -> IntentionRefineResponse:
    """
    Pre-session intention refiner.
    Security: User UUID derived strictly from JWT. Intention treated as untrusted text.
    Non-blocking, debounced on client, rule fallback on any error.
    """
    return service.refine_intention(payload.raw_intention, authed_user)


@router.post("/session-debrief", response_model=SessionDebriefResponse)
def get_session_debrief(
    payload: SessionDebriefRequest,
    authed_user: Annotated[str, Depends(require_auth)],
    service: Annotated[AiCoachService, Depends(_service)],
) -> SessionDebriefResponse:
    """
    Post-session debrief generator.
    Security: Carries only session_id. Verified that session belongs to authed_user.
    All stats, minute offsets, and aggregates computed server-side.
    Under 5 sessions: Cold start protection enforces zero personal claims.
    """
    return service.generate_session_debrief(payload.session_id, authed_user)


@router.post("/feedback")
def submit_coach_feedback(
    payload: CoachFeedbackRequest,
    authed_user: Annotated[str, Depends(require_auth)],
    service: Annotated[AiCoachService, Depends(_service)],
) -> Dict[str, Any]:
    """Submit user feedback (-1, 0, 1) on a generated insight."""
    success = service.update_feedback(payload.insight_id, payload.feedback, authed_user)
    return {"ok": success}
