from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.sensitivity import Sensitivity
from app.schemas.sensitivity import DataLevel
from app.schemas.tag import MAX_TAGS_PER_TARGET, TagSummary

MAX_TITLE_LENGTH = 160
MAX_CONTENT_LENGTH = 20000
MAX_LINKS = 20
MAX_LINK_LABEL_LENGTH = 120
MAX_ITEMS_PER_USER = 2000
MAX_ATTACHMENTS_PER_ITEM = 10
MAX_ATTACHMENT_BYTES = 5 * 1024 * 1024
GRAPH_MAX_NODES = 300


def _clean_title(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("título vazio")
    return stripped


class KnowledgeLink(BaseModel):
    """Link externo guardado junto do conhecimento."""

    url: str = Field(min_length=8, max_length=500)
    label: str | None = Field(default=None, max_length=MAX_LINK_LABEL_LENGTH)

    @field_validator("url")
    @classmethod
    def validate_url(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped.startswith(("http://", "https://")):
            raise ValueError("endereço inválido")
        return stripped

    @field_validator("label")
    @classmethod
    def clean_label(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        return stripped or None


class KnowledgeCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=MAX_TITLE_LENGTH)
    content: str | None = Field(default=None, max_length=MAX_CONTENT_LENGTH)
    links: list[KnowledgeLink] = Field(default_factory=list, max_length=MAX_LINKS)
    tag_ids: list[int] = Field(default_factory=list, max_length=MAX_TAGS_PER_TARGET)
    sensitivity: DataLevel = Sensitivity.PUBLIC

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str) -> str:
        return _clean_title(value)

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.rstrip()
        return stripped or None


class KnowledgeUpdateRequest(BaseModel):
    """Campo ausente não muda; `content` ou `links` vazios limpam o campo."""

    title: str | None = Field(default=None, min_length=1, max_length=MAX_TITLE_LENGTH)
    content: str | None = Field(default=None, max_length=MAX_CONTENT_LENGTH)
    links: list[KnowledgeLink] | None = Field(default=None, max_length=MAX_LINKS)
    tag_ids: list[int] | None = Field(default=None, max_length=MAX_TAGS_PER_TARGET)
    sensitivity: DataLevel | None = None

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return _clean_title(value)

    @field_validator("content")
    @classmethod
    def clean_content(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.rstrip()
        return stripped or None


class KnowledgeRelationRequest(BaseModel):
    target_id: int = Field(gt=0)


class KnowledgeGoalRequest(BaseModel):
    goal_id: int = Field(gt=0)


class AttachmentResponse(BaseModel):
    id: int
    filename: str
    content_type: str
    size_bytes: int
    download_url: str


class RelationReference(BaseModel):
    id: int
    title: str


class GoalReference(BaseModel):
    id: int
    title: str


class KnowledgeItemResponse(BaseModel):
    id: int
    title: str
    content: str | None
    links: list[KnowledgeLink]
    sensitivity: DataLevel
    relations: list[RelationReference]
    goals: list[GoalReference]
    tags: list[TagSummary]
    attachments: list[AttachmentResponse]
    created_at: datetime
    updated_at: datetime


class GraphNode(BaseModel):
    id: int
    title: str
    degree: int
    sensitivity: DataLevel = Sensitivity.PUBLIC
    tags: list[TagSummary] = []


class GraphEdge(BaseModel):
    source: int
    target: int


class KnowledgeGraphResponse(BaseModel):
    nodes: list[GraphNode]
    edges: list[GraphEdge]


def stored_links(links: list[KnowledgeLink] | None) -> list[dict]:
    """Forma gravada na coluna JSON."""
    return [
        {"url": link.url, "label": link.label} for link in (links or [])
    ]
