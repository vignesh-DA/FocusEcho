from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from supabase import Client, create_client

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
def upsert_batch(payload: DistractionEventBatch) -> dict[str, Any]:
    client = _client()
    rows = [event.model_dump(mode="json") for event in payload.events]
    client.table("distraction_events").upsert(rows).execute()
    return {"inserted": len(rows)}


@router.get("/{session_id}")
def get_session_events(session_id: str) -> list[dict[str, Any]]:
    client = _client()
    res = client.table("distraction_events").select("*").eq("session_id", session_id).execute()
    return list(res.data or [])


@router.post("/{event_id}/recover")
def recover_event(event_id: str) -> dict[str, Any]:
    client = _client()
    row = client.table("distraction_events").select("*").eq("id", event_id).maybe_single().execute().data
    if not row:
        raise HTTPException(status_code=404, detail="Event not found")

    triggered = datetime.fromisoformat(str(row["triggered_at"]).replace("Z", "+00:00"))
    now = datetime.now(timezone.utc)
    seconds = int((now - triggered).total_seconds())
    client.table("distraction_events").update(
        {"is_recovered": True, "recovered_at": now.isoformat(), "recovery_time_seconds": seconds}
    ).eq("id", event_id).execute()
    return {"event_id": event_id, "recovery_time_seconds": seconds}
