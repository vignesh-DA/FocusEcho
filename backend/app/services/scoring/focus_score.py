from __future__ import annotations

import math
from typing import Iterable


def explain_focus_score(events: Iterable[dict], session_minutes: int) -> dict:
    """Calculate the existing score and expose deterministic contributing factors."""
    distractions = [event for event in events if event.get("event_type", "distraction") == "distraction"]
    total = len(distractions)
    recovered = sum(1 for event in distractions if event.get("is_recovered"))
    average_recovery = (
        sum(float(event.get("recovery_time_seconds") or 0) for event in distractions) / total
        if total
        else 0.0
    )
    critical = sum(1 for event in distractions if event.get("risk_score") == "CRITICAL")
    # These components intentionally sum to the legacy formula: 100, plus a
    # capped duration bonus, minus distraction, recovery, and critical-event
    # penalties.  This keeps historical scores comparable.
    distraction_control = max(0.0, 60.0 - (15 * math.log(total + 1, 2) if total else 0.0) - critical * 10)
    recovery_points = max(0.0, 20.0 - min(20.0, average_recovery / 60))
    consistency_points = 20.0
    duration_points = min(
        20.0,
        max(0.0, session_minutes // 10 * 2),
        max(0.0, 100.0 - distraction_control - recovery_points - consistency_points),
    )
    score = round(min(100.0, duration_points + distraction_control + recovery_points + consistency_points), 1)

    positive: list[str] = []
    negative: list[str] = []
    if session_minutes >= 25:
        positive.append(f"Completed a {session_minutes}-minute session")
    if recovered:
        positive.append(f"Recovered from {recovered} distraction{'s' if recovered != 1 else ''}")
    if total == 0:
        positive.append("Maintained a distraction-free session")
    if total:
        negative.append(f"{total} distraction{'s' if total != 1 else ''}")
    if average_recovery >= 60:
        negative.append("Slow average recovery time")
    if critical:
        negative.append(f"{critical} critical distraction{'s' if critical != 1 else ''}")
    return {
        "score": score,
        "breakdown": {
            "focus_duration": round(duration_points, 1),
            "distraction_control": round(distraction_control, 1),
            "recovery": round(recovery_points, 1),
            "consistency": round(consistency_points, 1),
        },
        "positive_factors": positive,
        "negative_factors": negative,
    }
