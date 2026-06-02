from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class FocusSessionCreate(BaseModel):
    id: str
    user_id: str
    start_time: datetime
    end_time: Optional[datetime] = None
    productive_app: str
    total_distractions: int = 0
    total_xp_earned: int = 0
    focus_score: float = 0.0
    status: str = "active"


class FocusSessionUpdate(BaseModel):
    end_time: Optional[datetime] = None
    total_distractions: Optional[int] = None
    total_xp_earned: Optional[int] = None
    focus_score: Optional[float] = None
    status: Optional[str] = None


class FocusSessionResponse(FocusSessionCreate):
    created_at: datetime
