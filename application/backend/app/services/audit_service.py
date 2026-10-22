from dataclasses import dataclass
from datetime import date

from sqlalchemy.orm import Session

from atena_pattern.core.errors import AppError
from atena_pattern.core.request_context import client_day
from app.models.audit import AuditArea, AuditEvent, AuditKind
from atena_pattern.models.user import utc_now
from app.repositories.audit_repository import AuditRepository
from app.schemas.audit import (
    AuditDayResponse,
    AuditGraphEdge,
    AuditGraphNode,
    AuditGraphResponse,
)

MAX_RANGE_DAYS = 366
MAX_GRAPH_EVENTS = 500


@dataclass(frozen=True)
class AuditRef:
    """Registro citado por uma ação: tipo estável, referência e rótulo."""

    type: str
    ref: str
    label: str

    @property
    def key(self) -> str:
        return f"{self.type}:{self.ref}"


class AuditService:
    """Grava a ação do dia e entrega o histórico e o grafo daquele dia.

    Não faz commit: a gravação entra na transação de quem agiu, para a ação e
    o registro dela nunca ficarem separados.
    """

    def __init__(self, session: Session, user_id: int) -> None:
        self.session = session
        self.user_id = user_id
        self.events = AuditRepository(session)

    def record(
        self,
        *,
        area: AuditArea,
        kind: AuditKind,
        source: AuditRef,
        target: AuditRef | None = None,
    ) -> None:
        occurred_at = utc_now()
        self.session.add(
            AuditEvent(
                user_id=self.user_id,
                day=client_day(occurred_at),
                occurred_at=occurred_at,
                area=area,
                kind=kind,
                source_type=source.type,
                source_ref=source.ref,
                source_label=source.label[:160],
                target_type=target.type if target else None,
                target_ref=target.ref if target else None,
                target_label=target.label[:160] if target else None,
            )
        )

    def list_day(
        self, day: date, *, offset: int, limit: int
    ) -> tuple[list[AuditEvent], int]:
        return self.events.list_day(self.user_id, day, offset, limit)

    def days(self, start: date, end: date) -> list[AuditDayResponse]:
        if start > end:
            raise AppError(
                code="AUDIT_INVALID_RANGE",
                message="A data inicial precisa ser anterior à data final.",
                status_code=422,
            )
        if (end - start).days + 1 > MAX_RANGE_DAYS:
            raise AppError(
                code="AUDIT_RANGE_TOO_LARGE",
                message="O período máximo consultado é de um ano.",
                status_code=422,
            )
        return [
            AuditDayResponse(day=day, total=total)
            for day, total in self.events.day_counts(self.user_id, start, end)
        ]

    def graph(self, day: date) -> AuditGraphResponse:
        rows = self.events.events_for_day(
            self.user_id, day, MAX_GRAPH_EVENTS + 1
        )
        truncated = len(rows) > MAX_GRAPH_EVENTS
        rows = rows[:MAX_GRAPH_EVENTS]

        day_ref = AuditRef("day", day.isoformat(), day.isoformat())
        nodes: dict[str, AuditRef] = {}
        degrees: dict[str, int] = {}
        edges: dict[tuple[str, str], int] = {}

        def add_node(ref: AuditRef) -> None:
            nodes.setdefault(ref.key, ref)
            degrees.setdefault(ref.key, 0)

        def add_edge(first: AuditRef, second: AuditRef) -> None:
            if first.key == second.key:
                return
            pair = tuple(sorted((first.key, second.key)))
            edges[pair] = edges.get(pair, 0) + 1
            degrees[first.key] = degrees.get(first.key, 0) + 1
            degrees[second.key] = degrees.get(second.key, 0) + 1

        for event in rows:
            add_node(day_ref)
            source = _ref_of(event)
            add_node(source)
            add_edge(day_ref, source)
            target = _target_of(event)
            if target is not None:
                add_node(target)
                add_edge(day_ref, target)
                add_edge(source, target)

        ordered = sorted(
            nodes.values(),
            key=lambda ref: (-degrees.get(ref.key, 0), ref.label.lower()),
        )
        return AuditGraphResponse(
            day=day,
            nodes=[
                AuditGraphNode(
                    id=ref.key,
                    type=ref.type,
                    label=ref.label,
                    degree=degrees.get(ref.key, 0),
                )
                for ref in ordered
            ],
            edges=[
                AuditGraphEdge(source=source, target=target, count=count)
                for (source, target), count in sorted(edges.items())
            ],
            total_events=len(rows),
            truncated=truncated,
        )


def _ref_of(event: AuditEvent) -> AuditRef:
    return AuditRef(event.source_type, event.source_ref, event.source_label)


def _target_of(event: AuditEvent) -> AuditRef | None:
    if event.target_type is None or event.target_ref is None:
        return None
    return AuditRef(
        event.target_type, event.target_ref, event.target_label or ""
    )
