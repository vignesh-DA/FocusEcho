from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator


DRIFT_REASONS = {"bored", "stuck", "tired", "notification", "other"}


class FocusSessionReflectionFields(BaseModel):
    intent: Optional[str] = None
    focus_rating: Optional[int] = Field(default=None, ge=1, le=5)
    drift_reason: Optional[str] = None
    parked_items: Optional[List[str]] = Field(default=None, max_length=20)

    @field_validator("drift_reason")
    @classmethod
    def validate_drift_reason(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and value not in DRIFT_REASONS:
            raise ValueError("drift_reason must be one of the supported values")
        return value

    @field_validator("parked_items")
    @classmethod
    def validate_parked_items(cls, values: Optional[List[str]]) -> Optional[List[str]]:
        if values is not None and any(not isinstance(item, str) or len(item) > 120 for item in values):
            raise ValueError("parked items must be strings of at most 120 characters")
        return values


class FocusSessionCreate(FocusSessionReflectionFields):
    id: str
    user_id: str
    start_time: datetime
    end_time: Optional[datetime] = None
    productive_app: str
    total_distractions: int = 0
    total_xp_earned: int = 0
    focus_score: float = 0.0
    status: str = "active"


class FocusSessionUpdate(FocusSessionReflectionFields):
    end_time: Optional[datetime] = None
    total_distractions: Optional[int] = None
    total_xp_earned: Optional[int] = None
    focus_score: Optional[float] = None
    status: Optional[str] = None


class FocusSessionResponse(FocusSessionCreate):
    created_at: datetime
