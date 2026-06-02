from typing import Any

from fastapi import APIRouter, Body, HTTPException
from supabase import create_client

from ...schemas.focus_session import FocusSessionCreate, FocusSessionUpdate

router = APIRouter(prefix="/api/v1/sessions", tags=["sessions"])


def _client():
    from os import getenv

    url = getenv("SUPABASE_URL", "")
    key = getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        raise HTTPException(status_code=500, detail="Supabase env not configured")
    return create_client(url, key)


@router.post("/")
def create_session(payload: FocusSessionCreate) -> dict[str, Any]:
    _client().table("focus_sessions").upsert(payload.model_dump(mode="json")).execute()
    return {"id": payload.id}


@router.patch("/{session_id}")
def update_session(
    session_id: str,
    payload: FocusSessionUpdate = Body(
        ...,
        description="Partial focus session update object (JSON object, not an array).",
        example={
            "end_time": "2026-04-16T10:10:00Z",
            "total_distractions": 2,
            "total_xp_earned": 25,
            "focus_score": 82.5,
            "status": "completed",
        },
    ),
) -> dict[str, Any]:
    _client().table("focus_sessions").update(payload.model_dump(exclude_none=True, mode="json")).eq("id", session_id).execute()
    return {"updated": True}
