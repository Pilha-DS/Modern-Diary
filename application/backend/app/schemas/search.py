from datetime import date, datetime
from enum import StrEnum

from pydantic import BaseModel


class SearchType(StrEnum):
    """Áreas cobertas pela pesquisa universal."""

    KNOWLEDGE = "knowledge"
    GOAL = "goal"
    NOTE = "note"
    AGENDA_NOTE = "agenda_note"
    ACTIVITY = "activity"


class SearchResultResponse(BaseModel):
    type: SearchType
    ref: str
    title: str | None = None
    snippet: str | None = None
    day: date | None = None
    sensitivity: str
    updated_at: datetime
