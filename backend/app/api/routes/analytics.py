from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException
from supabase import Client, create_client

from ..auth import require_auth

router = APIRouter(prefix="/api/v1/analytics", tags=["analytics"])


def _client() -> Client:
    from os import getenv

    url = getenv("SUPABASE_URL", "")
    key = getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        raise HTTPException(status_code=500, detail="Supabase env not configured")
    return create_client(url, key)


@router.get("/summary/{user_id}")
def summary(
    user_id: str,
    authed_user: Annotated[str, Depends(require_auth)],
) -> dict[str, Any]:
    # C3 fix: callers may only read their own analytics.
    if authed_user != user_id:
        raise HTTPException(status_code=403, detail="Access denied: user_id mismatch.")

    client = _client()
    sessions = (
        client.table("focus_sessions")
        .select("*")
        .eq("user_id", user_id)
        .limit(30)
        .execute()
        .data
        or []
    )
    # C3 fix: events are filtered by session_id list, not fetched globally.
    session_ids = [s["id"] for s in sessions]
    events: list[dict[str, Any]] = []
    if session_ids:
        events = (
            client.table("distraction_events")
            .select("*")
            .in_("session_id", session_ids)
            .execute()
            .data
            or []
        )

    avg_focus = round(
        sum(float(s.get("focus_score", 0)) for s in sessions) / max(len(sessions), 1),
        2,
    )
    app_counts = Counter(e.get("app_label", "Unknown") for e in events)
    return {
        "weekly_sessions": len(sessions),
        "focus_score_average": avg_focus,
        "top_distracting_apps": app_counts.most_common(5),
    }


@router.get("/sessions/{user_id}")
def sessions(
    user_id: str,
    authed_user: Annotated[str, Depends(require_auth)],
) -> list[dict[str, Any]]:
    if authed_user != user_id:
        raise HTTPException(status_code=403, detail="Access denied: user_id mismatch.")

    client = _client()
    rows = (
        client.table("focus_sessions")
        .select("*")
        .eq("user_id", user_id)
        .order("start_time", desc=True)
        .limit(30)
        .execute()
        .data
        or []
    )
    return list(rows)


@router.get("/risk-trend/{user_id}")
def risk_trend(
    user_id: str,
    authed_user: Annotated[str, Depends(require_auth)],
) -> list[dict[str, Any]]:
    if authed_user != user_id:
        raise HTTPException(status_code=403, detail="Access denied: user_id mismatch.")

    client = _client()
    # C3 fix: fetch via sessions to scope to this user.
    session_rows = (
        client.table("focus_sessions")
        .select("id")
        .eq("user_id", user_id)
        .execute()
        .data
        or []
    )
    session_ids = [r["id"] for r in session_rows]
    events: list[dict[str, Any]] = []
    if session_ids:
        events = (
            client.table("distraction_events")
            .select("triggered_at,risk_score")
            .in_("session_id", session_ids)
            .execute()
            .data
            or []
        )

    cutoff = datetime.now(timezone.utc) - timedelta(days=14)
    grouped: dict[str, list[str]] = defaultdict(list)
    for event in events:
        ts = datetime.fromisoformat(str(event["triggered_at"]).replace("Z", "+00:00"))
        if ts >= cutoff:
            grouped[ts.date().isoformat()].append(str(event.get("risk_score", "SAFE")))

    daily = []
    for day, risks in sorted(grouped.items()):
        daily.append({"date": day, "risk_scores": risks})
    return daily
