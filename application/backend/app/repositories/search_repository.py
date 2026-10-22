from datetime import date

from sqlalchemy import Date, String, cast, func, literal, null, or_, select, text
from sqlalchemy.orm import Session

from app.models.agenda import AgendaActivity, AgendaNote
from app.models.goal import Goal
from app.models.knowledge import KnowledgeItem
from app.models.note import Note
from atena_pattern.models.sensitivity import Sensitivity
from app.models.tag import Tag, TagLink, TagTarget

#: Tamanho da prévia devolvida na pesquisa.
SNIPPET_LENGTH = 200


class SearchRepository:
    """Uma consulta única sobre todas as áreas, paginada no banco.

    Cada área vira um `SELECT` com as mesmas colunas e o conjunto é unido com
    `UNION ALL`; só então a página é cortada (`LIMIT`/`OFFSET`). Assim a ordem
    e a paginação valem para o resultado inteiro, não por área.
    """

    def __init__(self, session: Session) -> None:
        self.session = session

    def search(
        self,
        *,
        user_id: int,
        term: str,
        types: list[str],
        criteria: dict[str, list],
        tag_id: int | None,
        level: Sensitivity | None,
        from_day: date | None,
        to_day: date | None,
        offset: int,
        limit: int,
    ) -> tuple[list[tuple], int]:
        branches = [
            branch
            for type_value in types
            if (branch := self._branch(
                type_value,
                user_id=user_id,
                term=term,
                criteria=criteria.get(type_value),
                tag_id=tag_id,
                level=level,
                from_day=from_day,
                to_day=to_day,
            )) is not None
        ]
        if not branches:
            return [], 0

        combined = branches[0].union_all(*branches[1:])
        total = (
            self.session.scalar(
                select(func.count()).select_from(combined.subquery())
            )
            or 0
        )
        rows = self.session.execute(
            combined.order_by(
                text("updated_at DESC"),
                text("type"),
                text("ref DESC"),
            )
            .offset(offset)
            .limit(limit)
        ).all()
        return [tuple(row) for row in rows], total

    def _branch(
        self,
        type_value: str,
        *,
        user_id: int,
        term: str,
        criteria: list | None,
        tag_id: int | None,
        level: Sensitivity | None,
        from_day: date | None,
        to_day: date | None,
    ):
        """`SELECT` de uma área, ou `None` quando o filtro a exclui."""
        if criteria is None:
            return None
        if tag_id is not None and type_value not in ("knowledge", "goal"):
            return None

        match type_value:
            case "knowledge":
                return self._select(
                    type_value,
                    id_column=KnowledgeItem.id,
                    title=KnowledgeItem.title,
                    snippet=KnowledgeItem.content,
                    day=None,
                    sensitivity=KnowledgeItem.sensitivity,
                    updated_at=KnowledgeItem.updated_at,
                    filters=[
                        KnowledgeItem.user_id == user_id,
                        *self._term(
                            (KnowledgeItem.title, KnowledgeItem.content), term
                        ),
                        *self._period(
                            func.date(KnowledgeItem.updated_at), from_day, to_day
                        ),
                        *self._tag(
                            user_id, tag_id, TagTarget.KNOWLEDGE, KnowledgeItem.id
                        ),
                        *self._level(KnowledgeItem.sensitivity, level),
                        *criteria,
                    ],
                )
            case "goal":
                return self._select(
                    type_value,
                    id_column=Goal.id,
                    title=Goal.title,
                    snippet=Goal.description,
                    day=None,
                    sensitivity=Goal.sensitivity,
                    updated_at=Goal.updated_at,
                    filters=[
                        Goal.user_id == user_id,
                        *self._term((Goal.title, Goal.description), term),
                        *self._period(
                            func.date(Goal.updated_at), from_day, to_day
                        ),
                        *self._tag(user_id, tag_id, TagTarget.GOAL, Goal.id),
                        *self._level(Goal.sensitivity, level),
                        *criteria,
                    ],
                )
            case "note":
                return self._select(
                    type_value,
                    id_column=Note.id,
                    title=Note.title,
                    snippet=Note.content,
                    day=None,
                    sensitivity=Note.sensitivity,
                    updated_at=Note.updated_at,
                    filters=[
                        Note.user_id == user_id,
                        *self._term((Note.title, Note.content), term),
                        *self._period(
                            func.date(Note.updated_at), from_day, to_day
                        ),
                        *self._level(Note.sensitivity, level),
                        *criteria,
                    ],
                )
            case "agenda_note":
                return self._select(
                    type_value,
                    id_column=AgendaNote.id,
                    title=None,
                    snippet=AgendaNote.content,
                    day=AgendaNote.day,
                    sensitivity=AgendaNote.sensitivity,
                    updated_at=AgendaNote.updated_at,
                    filters=[
                        AgendaNote.user_id == user_id,
                        *self._term((AgendaNote.content,), term),
                        *self._period(AgendaNote.day, from_day, to_day),
                        *self._level(AgendaNote.sensitivity, level),
                        *criteria,
                    ],
                )
            case "activity":
                return self._select(
                    type_value,
                    id_column=AgendaActivity.id,
                    title=AgendaActivity.title,
                    snippet=None,
                    day=AgendaActivity.day,
                    sensitivity=AgendaActivity.sensitivity,
                    updated_at=AgendaActivity.updated_at,
                    filters=[
                        AgendaActivity.user_id == user_id,
                        *self._term((AgendaActivity.title,), term),
                        *self._period(AgendaActivity.day, from_day, to_day),
                        *self._level(AgendaActivity.sensitivity, level),
                        *criteria,
                    ],
                )
        return None

    @staticmethod
    def _select(
        type_value: str,
        *,
        id_column,
        title,
        snippet,
        day,
        sensitivity,
        updated_at,
        filters: list,
    ):
        return select(
            literal(type_value).label("type"),
            cast(id_column, String).label("ref"),
            (title if title is not None else cast(null(), String)).label("title"),
            func.substr(snippet, 1, SNIPPET_LENGTH).label("snippet")
            if snippet is not None
            else cast(null(), String).label("snippet"),
            (day if day is not None else cast(null(), Date)).label("day"),
            sensitivity.label("sensitivity"),
            updated_at.label("updated_at"),
        ).where(*filters)

    def _term(self, columns: tuple, term: str) -> list:
        # No MySQL a busca usa o índice FULLTEXT da migration; no SQLite
        # (testes) cai no LIKE, como já acontece na busca de notas.
        if self.session.get_bind().dialect.name == "mysql":
            target = ", ".join(
                f"{column.table.name}.{column.name}" for column in columns
            )
            return [
                text(
                    f"MATCH ({target}) AGAINST (:term IN BOOLEAN MODE)"
                ).bindparams(term=f"{term}*")
            ]
        pattern = f"%{term.lower()}%"
        return [or_(*(func.lower(column).like(pattern) for column in columns))]

    @staticmethod
    def _period(column, from_day: date | None, to_day: date | None) -> list:
        filters = []
        if from_day is not None:
            filters.append(column >= from_day)
        if to_day is not None:
            filters.append(column <= to_day)
        return filters

    @staticmethod
    def _level(column, level: Sensitivity | None) -> list:
        if level is None:
            return []
        return [column == level]

    @staticmethod
    def _tag(user_id: int, tag_id: int | None, target: TagTarget, id_column) -> list:
        if tag_id is None:
            return []
        return [
            id_column.in_(
                select(TagLink.target_id)
                .join(Tag, Tag.id == TagLink.tag_id)
                .where(
                    Tag.user_id == user_id,
                    TagLink.tag_id == tag_id,
                    TagLink.target_type == target,
                )
            )
        ]
