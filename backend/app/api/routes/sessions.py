from typing import Annotated, Any

from fastapi import APIRouter, Body, Depends, HTTPException
from supabase import create_client

from ..auth import require_auth
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
def create_session(
    payload: FocusSessionCreate,
    authed_user: Annotated[str, Depends(require_auth)],
) -> dict[str, Any]:
    if authed_user != payload.user_id:
        raise HTTPException(status_code=403, detail="Access denied: user_id mismatch.")
    client = _client()
    existing_res = (
        client.table("focus_sessions")
        .select("id,user_id")
        .eq("id", payload.id)
        .maybe_single()
        .execute()
    )
    existing = existing_res.data if existing_res and hasattr(existing_res, "data") else None
    if existing:
        if str(existing.get("user_id")) != authed_user:
            raise HTTPException(status_code=403, detail="Session ID is already owned by another user.")
        return {"id": payload.id}
    client.table("focus_sessions").insert(payload.model_dump(mode="json")).execute()
    return {"id": payload.id}


@router.patch("/{session_id}")
def update_session(
    session_id: str,
    authed_user: Annotated[str, Depends(require_auth)],
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
    client = _client()
    # Verify ownership before updating.
    session_res = (
        client.table("focus_sessions")
        .select("user_id")
        .eq("id", session_id)
        .maybe_single()
        .execute()
    )
    session = session_res.data if session_res and hasattr(session_res, "data") else None
    if not session:
        raise HTTPException(status_code=404, detail="Session not found.")
    if session["user_id"] != authed_user:
        raise HTTPException(status_code=403, detail="Access denied.")

    client.table("focus_sessions").update(
        payload.model_dump(exclude_none=True, mode="json")
    ).eq("id", session_id).execute()
    return {"updated": True}
