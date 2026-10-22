from datetime import date

from pydantic import BaseModel, Field, field_validator

from app.models.life_link import LinkType

MAX_NODE_REF_LENGTH = 40


class LifeNode(BaseModel):
    id: str
    type: LinkType
    ref: str
    title: str | None = None
    day: date | None = None
    degree: int = 0


class LifeEdge(BaseModel):
    source: str
    target: str
    kind: str
    link_id: int | None = None


class LifeGraphResponse(BaseModel):
    nodes: list[LifeNode]
    edges: list[LifeEdge]
    truncated: bool = False


class LifeLinkRequest(BaseModel):
    source_type: LinkType
    source_ref: str = Field(min_length=1, max_length=MAX_NODE_REF_LENGTH)
    target_type: LinkType
    target_ref: str = Field(min_length=1, max_length=MAX_NODE_REF_LENGTH)

    @field_validator("source_ref", "target_ref")
    @classmethod
    def clean_ref(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("referência vazia")
        return stripped
