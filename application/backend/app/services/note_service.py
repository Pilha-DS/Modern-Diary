from sqlalchemy.orm import Session

from app.core.access import AccessGuard, Actor
from app.core.errors import AppError
from app.models.api_secret import AuditAction
from app.models.area import Area
from app.models.note import Note
from app.models.sensitivity import Sensitivity
from app.repositories.note_repository import NoteRepository
from app.schemas.note import MAX_NOTES_PER_USER


class NoteService:
    def __init__(self, session: Session, actor: Actor) -> None:
        self.session = session
        self.actor = actor
        self.access = AccessGuard(session, actor)
        self.notes = NoteRepository(session)

    def list_notes(
        self,
        *,
        offset: int,
        limit: int,
        query: str | None = None,
        pinned: bool | None = None,
    ) -> tuple[list[tuple], int]:
        return self.notes.list_page(
            self.actor.user_id,
            offset,
            limit,
            query=query,
            pinned=pinned,
            criteria=self.access.visible(Area.NOTE),
        )

    def get_note(self, note_id: int) -> Note:
        return self._get_note_or_fail(note_id)

    def create_note(
        self,
        *,
        title: str | None,
        content: str,
        sensitivity: Sensitivity,
    ) -> Note:
        self.access.ensure_create(Area.NOTE, target_type="note")
        if self.notes.count_notes(self.actor.user_id) >= MAX_NOTES_PER_USER:
            raise AppError(
                code="NOTE_LIMIT",
                message="Você já atingiu o limite de notas.",
                status_code=409,
            )

        note = Note(
            user_id=self.actor.user_id,
            title=title,
            content=content,
            sensitivity=sensitivity,
        )
        self.notes.add(note)
        self.session.flush()
        self.access.record_created(Area.NOTE, "note", note.id)
        self.session.commit()
        return note

    def update_note(
        self,
        note_id: int,
        *,
        title: str | None = None,
        change_title: bool = False,
        content: str | None = None,
        change_content: bool = False,
        is_pinned: bool | None = None,
        sensitivity: Sensitivity | None = None,
    ) -> Note:
        note = self._get_note_or_fail(note_id)
        self.access.ensure_write(
            Area.NOTE,
            note.sensitivity,
            target_type="note",
            target_id=note.id,
        )

        if change_title:
            note.title = title
        if change_content:
            note.content = content or note.content
        if is_pinned is not None:
            note.is_pinned = is_pinned
        if sensitivity is not None:
            self.access.ensure_new_level(Area.NOTE, sensitivity)
            note.sensitivity = sensitivity

        self.session.commit()
        return note

    def delete_note(self, note_id: int) -> None:
        note = self._get_note_or_fail(note_id)
        self.access.ensure_write(
            Area.NOTE,
            note.sensitivity,
            target_type="note",
            target_id=note.id,
            action=AuditAction.DELETE,
        )
        self.notes.remove(note)
        self.session.commit()

    def _get_note_or_fail(self, note_id: int) -> Note:
        note = self.notes.get(
            self.actor.user_id,
            note_id,
            self.access.visible(Area.NOTE),
        )
        if note is None:
            raise AppError(
                code="NOTE_NOT_FOUND",
                message="Nota não encontrada.",
                status_code=404,
            )
        return note
