from datetime import date

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.responses import api_response
from app.models.audit import AuditEvent
from app.models.user import User
from app.schemas.audit import AuditEntityResponse, AuditEventResponse
from app.schemas.pagination import PageParams, pagination_meta
from app.services.audit_service import MAX_GRAPH_EVENTS, AuditService

router = APIRouter(prefix="/audit", tags=["audit"])


def _event_payload(event: AuditEvent) -> dict:
    return AuditEventResponse(
        id=event.id,
        occurred_at=event.occurred_at,
        area=event.area,
        kind=event.kind,
        source=AuditEntityResponse(
            type=event.source_type,
            ref=event.source_ref,
            label=event.source_label,
        ),
        target=(
            AuditEntityResponse(
                type=event.target_type,
                ref=event.target_ref,
                label=event.target_label or "",
            )
            if event.target_type is not None and event.target_ref is not None
            else None
        ),
    ).model_dump(mode="json")


@router.get("/days", summary="Dias com ações no período")
def list_days(
    request: Request,
    start: date = Query(alias="from", description="Primeiro dia do período"),
    end: date = Query(alias="to", description="Último dia do período"),
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    days = AuditService(session, user.id).days(start, end)
    return api_response(
        request,
        code="AUDIT_DAYS_LISTED",
        data=[entry.model_dump(mode="json") for entry in days],
        meta={
            "from": start.isoformat(),
            "to": end.isoformat(),
            "total": sum(entry.total for entry in days),
        },
    )


@router.get("/days/{day}", summary="Histórico de ações de um dia")
def list_events(
    day: date,
    request: Request,
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    events, total = AuditService(session, user.id).list_day(
        day, offset=page.offset, limit=page.per_page
    )
    return api_response(
        request,
        code="AUDIT_LISTED",
        data=[_event_payload(event) for event in events],
        meta=pagination_meta(page.page, page.per_page, total),
    )


@router.get("/days/{day}/graph", summary="Grafo das ações de um dia")
def day_graph(
    day: date,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    graph = AuditService(session, user.id).graph(day)
    return api_response(
        request,
        code="AUDIT_GRAPH",
        data=graph.model_dump(mode="json"),
        meta={
            "max_events": MAX_GRAPH_EVENTS,
            "truncated": graph.truncated,
        },
    )
