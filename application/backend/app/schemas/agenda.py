from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict, Field, field_serializer, field_validator

from app.models.agenda import Priority
from app.models.sensitivity import Sensitivity
from app.schemas.sensitivity import DataLevel
from app.schemas.tag import MAX_TAGS_PER_TARGET, TagSummary

MAX_NOTE_LENGTH = 20000


class ActivityCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=120, examples=["Estudar FastAPI"])
    start_time: time | None = Field(default=None, examples=["09:30"])
    priority: Priority = Priority.MEDIUM
    sensitivity: DataLevel = Sensitivity.PUBLIC

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("título vazio")
        return stripped


class ActivityUpdateRequest(BaseModel):
    """Campo ausente não muda; `start_time: null` limpa o horário."""

    title: str | None = Field(default=None, min_length=1, max_length=120)
    start_time: time | None = None
    priority: Priority | None = None
    is_done: bool | None = None
    sensitivity: DataLevel | None = None

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        if not stripped:
            raise ValueError("título vazio")
        return stripped


class NoteCreateRequest(BaseModel):
    content: str = Field(min_length=1, max_length=MAX_NOTE_LENGTH)
    sensitivity: DataLevel = Sensitivity.PUBLIC

    @field_validator("content")
    @classmethod
    def strip_content(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("nota vazia")
        return stripped


class NoteUpdateRequest(BaseModel):
    """Campo ausente não muda a nota."""

    content: str | None = Field(default=None, min_length=1, max_length=MAX_NOTE_LENGTH)
    sensitivity: DataLevel | None = None

    @field_validator("content")
    @classmethod
    def strip_content(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        if not stripped:
            raise ValueError("nota vazia")
        return stripped


class DaySensitivityRequest(BaseModel):
    sensitivity: DataLevel


class DayTagsRequest(BaseModel):
    tag_ids: list[int] = Field(default_factory=list, max_length=MAX_TAGS_PER_TARGET)


class ActivityResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    start_time: time | None
    priority: Priority
    is_done: bool
    sensitivity: DataLevel

    @field_serializer("start_time")
    def serialize_start_time(self, value: time | None) -> str | None:
        return value.strftime("%H:%M") if value else None


class NoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    content: str
    sensitivity: DataLevel
    updated_at: datetime

    @field_serializer("updated_at")
    def serialize_updated_at(self, value: datetime) -> str:
        return value.isoformat()


class AgendaDayResponse(BaseModel):
    day: date
    sensitivity: DataLevel | None
    notes: list[NoteResponse]
    activities: list[ActivityResponse]
    tags: list[TagSummary]
    holiday: str | None

    @field_serializer("day")
    def serialize_day(self, value: date) -> str:
        return value.isoformat()


class AgendaSummaryDay(BaseModel):
    day: date
    has_note: bool
    activities_total: int
    activities_done: int
    highest_priority: Priority | None
    tags: list[TagSummary]
    holiday: str | None = None

    @field_serializer("day")
    def serialize_day(self, value: date) -> str:
        return value.isoformat()
