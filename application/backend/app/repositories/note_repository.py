from sqlalchemy import func, or_, select, text
from sqlalchemy.orm import Session

from app.models.note import Note
from app.schemas.note import PREVIEW_LENGTH


class NoteRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get(
        self, user_id: int, note_id: int, criteria: list | None = None
    ) -> Note | None:
        return self.session.scalar(
            select(Note).where(
                Note.id == note_id,
                Note.user_id == user_id,
                *(criteria or []),
            )
        )

    def list_page(
        self,
        user_id: int,
        offset: int,
        limit: int,
        *,
        query: str | None = None,
        pinned: bool | None = None,
        criteria: list | None = None,
    ) -> tuple[list[tuple], int]:
        """Página de resumos: só as colunas da listagem, com prévia do texto."""
        filters = [
            Note.user_id == user_id,
            *(self._search(query)),
            *(self._pinned(pinned)),
            *(criteria or []),
        ]
        total = self.session.scalar(
            select(func.count(Note.id)).where(*filters)
        ) or 0
        rows = self.session.execute(
            select(
                Note.id,
                Note.title,
                func.substr(Note.content, 1, PREVIEW_LENGTH),
                Note.is_pinned,
                Note.sensitivity,
                Note.created_at,
                Note.updated_at,
            )
            .where(*filters)
            .order_by(
                Note.is_pinned.desc(),
                Note.updated_at.desc(),
                Note.id.desc(),
            )
            .offset(offset)
            .limit(limit)
        ).all()
        return [tuple(row) for row in rows], total

    def count_notes(self, user_id: int) -> int:
        return (
            self.session.scalar(
                select(func.count(Note.id)).where(Note.user_id == user_id)
            )
            or 0
        )

    def add(self, note: Note) -> None:
        self.session.add(note)

    def remove(self, note: Note) -> None:
        self.session.delete(note)

    @staticmethod
    def _pinned(pinned: bool | None) -> list:
        if pinned is None:
            return []
        return [Note.is_pinned.is_(pinned)]

    def _search(self, query: str | None) -> list:
        term = " ".join((query or "").split())
        if not term:
            return []
        # No MySQL a busca usa o índice FULLTEXT da migration; no SQLite
        # (testes) cai no LIKE, que também respeita o filtro do usuário.
        if self.session.get_bind().dialect.name == "mysql":
            return [
                text(
                    "MATCH (notes.title, notes.content) "
                    "AGAINST (:term IN BOOLEAN MODE)"
                ).bindparams(term=f"{term}*")
            ]
        pattern = f"%{term.lower()}%"
        return [
            or_(
                func.lower(Note.title).like(pattern),
                func.lower(Note.content).like(pattern),
            )
        ]
