from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import get_actor
from app.core.access import Actor
from app.core.database import get_db
from app.core.responses import api_response
from app.models.note import Note
from app.schemas.note import (
    NoteCreateRequest,
    NoteResponse,
    NoteSummaryResponse,
    NoteUpdateRequest,
)
from app.schemas.pagination import PageParams, pagination_meta
from app.services.note_service import NoteService

router = APIRouter(prefix="/notes", tags=["notes"])

MAX_SEARCH_LENGTH = 120


def _summary_payload(row: tuple) -> dict:
    note_id, title, preview, is_pinned, sensitivity, created_at, updated_at = row
    return NoteSummaryResponse(
        id=note_id,
        title=title,
        preview=preview or "",
        is_pinned=is_pinned,
        sensitivity=sensitivity,
        created_at=created_at,
        updated_at=updated_at,
    ).model_dump(mode="json")


def _note_payload(note: Note) -> dict:
    return NoteResponse(
        id=note.id,
        title=note.title,
        content=note.content,
        is_pinned=note.is_pinned,
        sensitivity=note.sensitivity,
        created_at=note.created_at,
        updated_at=note.updated_at,
    ).model_dump(mode="json")


@router.get("", summary="Lista as notas paginadas")
def list_notes(
    request: Request,
    q: str | None = Query(
        default=None,
        max_length=MAX_SEARCH_LENGTH,
        description="Busca no título e no conteúdo",
    ),
    pinned: bool | None = Query(default=None, description="Filtra fixadas"),
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    rows, total = NoteService(session, actor).list_notes(
        offset=page.offset,
        limit=page.per_page,
        query=q,
        pinned=pinned,
    )
    return api_response(
        request,
        code="NOTES_LISTED",
        data=[_summary_payload(row) for row in rows],
        meta=pagination_meta(page.page, page.per_page, total),
    )


@router.post("", status_code=201, summary="Cria uma nota")
def create_note(
    payload: NoteCreateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    note = NoteService(session, actor).create_note(
        title=payload.title,
        content=payload.content,
        sensitivity=payload.sensitivity,
    )
    return api_response(
        request,
        code="NOTE_CREATED",
        data=_note_payload(note),
        message="Nota criada com sucesso.",
        status_code=201,
    )


@router.get("/{note_id}", summary="Detalhe de uma nota")
def get_note(
    note_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    note = NoteService(session, actor).get_note(note_id)
    return api_response(
        request,
        code="NOTE_RETRIEVED",
        data=_note_payload(note),
    )


@router.patch("/{note_id}", summary="Atualiza, fixa ou desafixa uma nota")
def update_note(
    note_id: int,
    payload: NoteUpdateRequest,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    note = NoteService(session, actor).update_note(
        note_id,
        title=payload.title,
        change_title="title" in payload.model_fields_set,
        content=payload.content,
        change_content="content" in payload.model_fields_set,
        is_pinned=payload.is_pinned,
        sensitivity=payload.sensitivity,
    )
    return api_response(
        request,
        code="NOTE_UPDATED",
        data=_note_payload(note),
        message="Nota atualizada com sucesso.",
    )


@router.delete("/{note_id}", summary="Exclui uma nota")
def delete_note(
    note_id: int,
    request: Request,
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    NoteService(session, actor).delete_note(note_id)
    return api_response(
        request,
        code="NOTE_DELETED",
        data={"id": note_id},
        message="Nota excluída com sucesso.",
    )
