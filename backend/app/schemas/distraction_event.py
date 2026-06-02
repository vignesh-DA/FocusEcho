from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel


class DistractionEventCreate(BaseModel):
    id: str
    session_id: str
    package_name: str
    app_label: str
    triggered_at: datetime
    recovered_at: Optional[datetime] = None
    recovery_time_seconds: Optional[int] = None
    risk_score: str
    event_type: Optional[str] = "distraction"
    app_category: Optional[str] = None
    time_away_seconds: Optional[int] = None
    risk_score_numeric: Optional[float] = None
    was_notification_triggered: Optional[bool] = None
    returned_to_origin: Optional[bool] = None
    switch_stack_depth: Optional[int] = None
    time_of_day_hour: Optional[int] = None
    day_of_week: Optional[int] = None
    session_minute_when_occurred: Optional[int] = None
    is_recovered: bool


class DistractionEventResponse(DistractionEventCreate):
    created_at: datetime


class DistractionEventBatch(BaseModel):
    events: List[DistractionEventCreate]
    user_id: str
