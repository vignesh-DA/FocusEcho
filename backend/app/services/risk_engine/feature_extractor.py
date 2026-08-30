from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Iterable


@dataclass(frozen=True)
class RiskFeatures:
    category: str
    time_away_seconds: int
    distractions_last_30_minutes: int
    repeated_same_app: int
    recovery_rate: float | None
    session_minutes: int
    hour: int
    weekday: int


def _timestamp(value: object) -> datetime | None:
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)


def extract_risk_features(events: Iterable[dict], current_event: dict | None = None) -> RiskFeatures:
    """Turn minimal event metadata into model-independent risk features.

    Raw notification contents and unrelated app activity are deliberately not
    included.  A future statistical model can consume this same feature set.
    """
    rows = [event for event in events if event.get("event_type", "distraction") == "distraction"]
    latest = current_event or (rows[-1] if rows else {})
    now = _timestamp(latest.get("triggered_at")) or datetime.now(timezone.utc)
    cutoff = now - timedelta(minutes=30)
    recent = [event for event in rows if (_timestamp(event.get("triggered_at")) or now) >= cutoff]
    package = str(latest.get("package_name") or "")
    same_app = sum(1 for event in recent if event.get("package_name") == package)
    recovered = [event for event in rows if event.get("is_recovered")]
    recovery_rate = len(recovered) / len(rows) if rows else None
    session_started = _timestamp(latest.get("session_started_at"))
    session_minutes = max(0, int((now - session_started).total_seconds() // 60)) if session_started else int(latest.get("session_minute_when_occurred") or 0)

    return RiskFeatures(
        category=str(latest.get("app_category") or "unknown"),
        time_away_seconds=max(0, int(latest.get("time_away_seconds") or 0)),
        distractions_last_30_minutes=len(recent),
        repeated_same_app=max(0, same_app - 1),
        recovery_rate=recovery_rate,
        session_minutes=session_minutes,
        hour=now.hour,
        weekday=now.weekday(),
    )
