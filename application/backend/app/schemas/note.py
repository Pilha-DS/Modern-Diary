from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.sensitivity import Sensitivity
from app.schemas.sensitivity import DataLevel

MAX_TITLE_LENGTH = 160
MAX_CONTENT_LENGTH = 50000
MAX_NOTES_PER_USER = 5000
PREVIEW_LENGTH = 280


def _clean_title(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = " ".join(value.split())
    return stripped or None


def _clean_content(value: str) -> str:
    stripped = value.rstrip()
    if not stripped.strip():
        raise ValueError("conteúdo vazio")
    return stripped


class NoteCreateRequest(BaseModel):
    title: str | None = Field(default=None, max_length=MAX_TITLE_LENGTH)
    content: str = Field(min_length=1, max_length=MAX_CONTENT_LENGTH)
    sensitivity: DataLevel = Sensitivity.PUBLIC

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str | None) -> str | None:
        return _clean_title(value)

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str) -> str:
        return _clean_content(value)


class NoteUpdateRequest(BaseModel):
    """Campo ausente não muda; `title` vazio limpa o título."""

    title: str | None = Field(default=None, max_length=MAX_TITLE_LENGTH)
    content: str | None = Field(default=None, max_length=MAX_CONTENT_LENGTH)
    is_pinned: bool | None = None
    sensitivity: DataLevel | None = None

    @field_validator("title")
    @classmethod
    def clean_title(cls, value: str | None) -> str | None:
        return _clean_title(value)

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _clean_content(value)


class NoteSummaryResponse(BaseModel):
    id: int
    title: str | None
    preview: str
    is_pinned: bool
    sensitivity: DataLevel
    created_at: datetime
    updated_at: datetime


class NoteResponse(BaseModel):
    id: int
    title: str | None
    content: str
    is_pinned: bool
    sensitivity: DataLevel
    created_at: datetime
    updated_at: datetime
