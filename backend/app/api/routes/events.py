from datetime import datetime, timezone
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException
from postgrest.exceptions import APIError as PostgrestAPIError
from supabase import Client, create_client

from ..auth import require_auth
from ...schemas.distraction_event import DistractionEventBatch

router = APIRouter(prefix="/api/v1/events", tags=["events"])


def _client() -> Client:
    from os import getenv

    url = getenv("SUPABASE_URL", "")
    key = getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        raise HTTPException(status_code=500, detail="Supabase env not configured")
    return create_client(url, key)


@router.post("/batch")
def upsert_batch(
    payload: DistractionEventBatch,
    authed_user: Annotated[str, Depends(require_auth)],
) -> dict[str, Any]:
    # Reject if the JWT user_id doesn't match the batch's declared user_id.
    if authed_user != payload.user_id:
        raise HTTPException(status_code=403, detail="Access denied: user_id mismatch.")

    client = _client()
    rows = [event.model_dump(mode="json") for event in payload.events]
    for row in rows:
        if row.get("was_notification_triggered") is None:
            row["was_notification_triggered"] = False
        if row.get("returned_to_origin") is None:
            row["returned_to_origin"] = False

    session_ids = list({row["session_id"] for row in rows})
    owned_session_rows = (
        client.table("focus_sessions")
        .select("id")
        .eq("user_id", authed_user)
        .in_("id", session_ids)
        .execute()
        .data
        or []
    )
    owned_session_ids = {str(row["id"]) for row in owned_session_rows}
    if owned_session_ids != set(session_ids):
        raise HTTPException(status_code=403, detail="One or more sessions are not owned by this user.")

    event_ids = list({row["id"] for row in rows})
    existing_events = (
        client.table("distraction_events")
        .select("id,session_id")
        .in_("id", event_ids)
        .execute()
        .data
        or []
    )
    existing_session_ids = list({str(row["session_id"]) for row in existing_events})
    if existing_session_ids:
        existing_owned_sessions = (
            client.table("focus_sessions")
            .select("id")
            .eq("user_id", authed_user)
            .in_("id", existing_session_ids)
            .execute()
            .data
            or []
        )
        if {str(row["id"]) for row in existing_owned_sessions} != set(existing_session_ids):
            raise HTTPException(status_code=403, detail="One or more events are not owned by this user.")

    try:
        client.table("distraction_events").upsert(rows).execute()
    except PostgrestAPIError as error:
        # PostgREST constraint errors should be a client response, not an
        # unhandled 500. Do not leak SQL, table details, or raw server text.
        code = str(getattr(error, "code", "") or "")
        if code == "23503":  # foreign-key violation
            raise HTTPException(
                status_code=400,
                detail="Event references a session that does not exist.",
            ) from None
        if code == "23505":  # duplicate event key
            raise HTTPException(
                status_code=409,
                detail="An event with this id already exists.",
            ) from None
        raise HTTPException(
            status_code=400,
            detail="Event batch violates the database schema.",
        ) from None
    return {"inserted": len(rows)}


@router.get("/{session_id}")
def get_session_events(
    session_id: str,
    authed_user: Annotated[str, Depends(require_auth)],
) -> list[dict[str, Any]]:
    client = _client()
    # Verify this session belongs to the authenticated user.
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

    res = (
        client.table("distraction_events")
        .select("*")
        .eq("session_id", session_id)
        .execute()
    )
    return list(res.data or [])


@router.post("/{event_id}/recover")
def recover_event(
    event_id: str,
    authed_user: Annotated[str, Depends(require_auth)],
) -> dict[str, Any]:
    client = _client()
    row_res = (
        client.table("distraction_events")
        .select("*")
        .eq("id", event_id)
        .maybe_single()
        .execute()
    )
    row = row_res.data if row_res and hasattr(row_res, "data") else None
    if not row:
        raise HTTPException(status_code=404, detail="Event not found")

    # Verify ownership via the parent session.
    session_res = (
        client.table("focus_sessions")
        .select("user_id")
        .eq("id", row["session_id"])
        .maybe_single()
        .execute()
    )
    session = session_res.data if session_res and hasattr(session_res, "data") else None
    if not session or session["user_id"] != authed_user:
        raise HTTPException(status_code=403, detail="Access denied.")

    triggered = datetime.fromisoformat(str(row["triggered_at"]).replace("Z", "+00:00"))
    now = datetime.now(timezone.utc)
    seconds = int((now - triggered).total_seconds())
    client.table("distraction_events").update(
        {"is_recovered": True, "recovered_at": now.isoformat(), "recovery_time_seconds": seconds}
    ).eq("id", event_id).execute()
    return {"event_id": event_id, "recovery_time_seconds": seconds}
