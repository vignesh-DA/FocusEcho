from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from supabase import Client, create_client

router = APIRouter(prefix="/api/v1/analytics", tags=["analytics"])


def _client() -> Client:
    from os import getenv

    url = getenv("SUPABASE_URL", "")
    key = getenv("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        raise HTTPException(status_code=500, detail="Supabase env not configured")
    return create_client(url, key)


@router.get("/summary/{user_id}")
def summary(user_id: str) -> dict[str, Any]:
    client = _client()
    sessions = client.table("focus_sessions").select("*").eq("user_id", user_id).limit(30).execute().data or []
    events = client.table("distraction_events").select("*").execute().data or []
    avg_focus = round(sum(float(s.get("focus_score", 0)) for s in sessions) / max(len(sessions), 1), 2)
    app_counts = Counter(e.get("app_label", "Unknown") for e in events)
    return {
      "weekly_sessions": len(sessions),
      "focus_score_average": avg_focus,
      "top_distracting_apps": app_counts.most_common(5),
    }


@router.get("/sessions/{user_id}")
def sessions(user_id: str) -> list[dict[str, Any]]:
    client = _client()
    rows = client.table("focus_sessions").select("*").eq("user_id", user_id).order("start_time", desc=True).limit(30).execute().data or []
    return list(rows)


@router.get("/risk-trend/{user_id}")
def risk_trend(user_id: str) -> list[dict[str, Any]]:
    client = _client()
    events = client.table("distraction_events").select("*").execute().data or []
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
