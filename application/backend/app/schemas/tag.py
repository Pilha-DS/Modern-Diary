import re
from datetime import date

from pydantic import BaseModel, Field, field_serializer, field_validator

from app.models.tag import Tag, TagTarget

MAX_TAG_NAME_LENGTH = 40
MAX_TAG_DESCRIPTION_LENGTH = 280
MAX_TAGS_PER_USER = 500
MAX_TAGS_PER_TARGET = 20
MAX_USAGES_PER_PAGE = 100

_COLOR_PATTERN = re.compile(r"^#[0-9A-Fa-f]{6}$")


def _clean_name(value: str) -> str:
    stripped = " ".join(value.split())
    if not stripped:
        raise ValueError("nome vazio")
    return stripped


def _clean_description(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


def _clean_color(value: str) -> str:
    stripped = value.strip()
    if not _COLOR_PATTERN.match(stripped):
        raise ValueError("cor inválida")
    return stripped.upper()


class TagCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=MAX_TAG_NAME_LENGTH)
    color: str = Field(default="#4A7BA7", max_length=7)
    description: str | None = Field(
        default=None,
        max_length=MAX_TAG_DESCRIPTION_LENGTH,
    )

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str) -> str:
        return _clean_name(value)

    @field_validator("color")
    @classmethod
    def check_color(cls, value: str) -> str:
        return _clean_color(value)

    @field_validator("description")
    @classmethod
    def strip_description(cls, value: str | None) -> str | None:
        return _clean_description(value)


class TagUpdateRequest(BaseModel):
    """Campo ausente não muda; `description: null` limpa a descrição."""

    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=MAX_TAG_NAME_LENGTH,
    )
    color: str | None = Field(default=None, max_length=7)
    description: str | None = Field(
        default=None,
        max_length=MAX_TAG_DESCRIPTION_LENGTH,
    )

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _clean_name(value)

    @field_validator("color")
    @classmethod
    def check_color(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _clean_color(value)

    @field_validator("description")
    @classmethod
    def strip_description(cls, value: str | None) -> str | None:
        return _clean_description(value)


class TagSummary(BaseModel):
    id: int
    name: str
    color: str
    description: str | None


class TagResponse(TagSummary):
    usage_count: int

    @classmethod
    def from_model(cls, tag: Tag, usage_count: int) -> "TagResponse":
        return cls(
            id=tag.id,
            name=tag.name,
            color=tag.color,
            description=tag.description,
            usage_count=usage_count,
        )


class TagUsageResponse(BaseModel):
    target_type: TagTarget
    target_id: int
    title: str | None
    day: date | None

    @field_serializer("day")
    def serialize_day(self, value: date | None) -> str | None:
        return value.isoformat() if value else None


def tag_summary(tag: Tag) -> TagSummary:
    return TagSummary(
        id=tag.id,
        name=tag.name,
        color=tag.color,
        description=tag.description,
    )
