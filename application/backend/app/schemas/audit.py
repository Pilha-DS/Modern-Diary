from datetime import date, datetime

from pydantic import BaseModel, field_serializer

from app.models.audit import AuditArea, AuditKind


class AuditEntityResponse(BaseModel):
    type: str
    ref: str
    label: str


class AuditEventResponse(BaseModel):
    id: int
    occurred_at: datetime
    area: AuditArea
    kind: AuditKind
    source: AuditEntityResponse
    target: AuditEntityResponse | None

    @field_serializer("occurred_at")
    def serialize_occurred_at(self, value: datetime) -> str:
        return value.isoformat(timespec="seconds") + "Z"


class AuditDayResponse(BaseModel):
    day: date
    total: int

    @field_serializer("day")
    def serialize_day(self, value: date) -> str:
        return value.isoformat()


class AuditGraphNode(BaseModel):
    id: str
    type: str
    label: str
    degree: int


class AuditGraphEdge(BaseModel):
    source: str
    target: str
    count: int


class AuditGraphResponse(BaseModel):
    day: date
    nodes: list[AuditGraphNode]
    edges: list[AuditGraphEdge]
    total_events: int
    truncated: bool

    @field_serializer("day")
    def serialize_day(self, value: date) -> str:
        return value.isoformat()
