from datetime import date

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import get_actor
from app.core.access import Actor
from app.core.database import get_db
from app.core.responses import api_response
from app.models.agenda import AgendaDay
from app.schemas.agenda import (
    ActivityCreateRequest,
    ActivityResponse,
    ActivityUpdateRequest,
    DayTagsRequest,
    SaveNoteRequest,
)
from app.services.agenda_service import AgendaService

router = APIRouter(prefix="/agenda", tags=["agenda"])


def _day_payload(
    day: date,
    note_row: AgendaDay | None,
    activities: list,
    tags: list,
) -> dict:
    return {
        "day": day.isoformat(),
        "note": note_row.note if note_row else None,
        "sensitivity": (
            note_row.sensitivity.api_value if note_row else None
        ),
        "activities": [
            ActivityResponse.model_validate(activity).model_dump(mode="json")
            for activity in activities
        ],
        "tags": [tag.model_dump(mode="json") for tag in tags],
    }


@router.get(
    "/summary",
    summary="Resume os dias com registro no período (máximo de um ano)",
)
def summarize(
    request: Request,
    start: date = Query(alias="from", description="Primeiro dia, YYYY-MM-DD"),
    end: date = Query(alias="to", description="Último dia, YYYY-MM-DD"),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    summaries = AgendaService(session, actor).summarize(start, end)
    return api_response(
        request,
        code="AGENDA_SUMMARY",
        data=[summary.model_dump(mode="json") for summary in summaries],
        meta={"from": start.isoformat(), "to": end.isoformat(), "total": len(summaries)},
    )


@router.get(
    "/days/{day}",
    response_model=None,
    summary="Nota e atividades de um dia",
)
def get_day(
    day: date,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    note_row, activities, tags = AgendaService(session, actor).get_day(day)
    return api_response(
        request,
        code="AGENDA_DAY_RETRIEVED",
        data=_day_payload(day, note_row, activities, tags),
    )


@router.put("/days/{day}/note", summary="Salva a nota do dia (markdown)")
def save_note(
    day: date,
    payload: SaveNoteRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = AgendaService(session, actor)
    service.save_note(day, payload.note, sensitivity=payload.sensitivity)
    note_row, activities, tags = service.get_day(day)
    return api_response(
        request,
        code="AGENDA_NOTE_SAVED",
        data=_day_payload(day, note_row, activities, tags),
        message="Nota salva com sucesso.",
    )


@router.put("/days/{day}/tags", summary="Define as tags do dia")
def set_day_tags(
    day: date,
    payload: DayTagsRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    service = AgendaService(session, actor)
    service.set_day_tags(day, payload.tag_ids)
    note_row, activities, tags = service.get_day(day)
    return api_response(
        request,
        code="AGENDA_DAY_TAGS_SAVED",
        data=_day_payload(day, note_row, activities, tags),
        message="Tags do dia atualizadas.",
    )


@router.post(
    "/days/{day}/activities",
    status_code=201,
    summary="Cria uma atividade no dia",
)
def create_activity(
    day: date,
    payload: ActivityCreateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    activity = AgendaService(session, actor).create_activity(
        day,
        title=payload.title,
        start_time=payload.start_time,
        priority=payload.priority,
        sensitivity=payload.sensitivity,
    )
    return api_response(
        request,
        code="AGENDA_ACTIVITY_CREATED",
        data=ActivityResponse.model_validate(activity).model_dump(mode="json"),
        message="Atividade criada com sucesso.",
        status_code=201,
    )


@router.patch("/activities/{activity_id}", summary="Atualiza uma atividade")
def update_activity(
    activity_id: int,
    payload: ActivityUpdateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    activity = AgendaService(session, actor).update_activity(
        activity_id,
        title=payload.title,
        start_time=payload.start_time,
        change_start_time="start_time" in payload.model_fields_set,
        priority=payload.priority,
        is_done=payload.is_done,
        sensitivity=payload.sensitivity,
    )
    return api_response(
        request,
        code="AGENDA_ACTIVITY_UPDATED",
        data=ActivityResponse.model_validate(activity).model_dump(mode="json"),
        message="Atividade atualizada com sucesso.",
    )


@router.delete("/activities/{activity_id}", summary="Exclui uma atividade")
def delete_activity(
    activity_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    AgendaService(session, actor).delete_activity(activity_id)
    return api_response(
        request,
        code="AGENDA_ACTIVITY_DELETED",
        data={"id": activity_id},
        message="Atividade excluída com sucesso.",
    )
