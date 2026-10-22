from dataclasses import dataclass
from datetime import date, datetime

from sqlalchemy import null, or_, select
from sqlalchemy.orm import Session

from app.models.agenda import AgendaActivity, AgendaDay
from app.models.goal import Goal, GoalStatus
from app.models.knowledge import KnowledgeGoalLink, KnowledgeItem, KnowledgeRelation
from app.models.life_link import EntityLink, LinkType
from app.models.note import Note
from app.models.sensitivity import Sensitivity


@dataclass(frozen=True)
class LifeEntityRow:
    """Registro que vira nó do grafo: tipo, referência e rótulo de origem."""

    type: LinkType
    ref: str
    title: str | None
    day: date | None
    sensitivity: Sensitivity
    updated_at: datetime

    @property
    def key(self) -> str:
        return f"{self.type.value}:{self.ref}"


class LifeRepository:
    """Consultas do grafo de vida e das ligações livres entre registros."""

    def __init__(self, session: Session) -> None:
        self.session = session

    def entities(
        self,
        user_id: int,
        types: list[LinkType],
        criteria: dict[LinkType, list],
        limit: int,
    ) -> list[LifeEntityRow]:
        rows: list[LifeEntityRow] = []
        for link_type in types:
            rows.extend(
                self._query(link_type, user_id, criteria.get(link_type, []), limit)
            )
        return rows

    def entities_by_refs(
        self,
        user_id: int,
        type_: LinkType,
        refs: list[str],
        criteria: list,
    ) -> list[LifeEntityRow]:
        ids = [int(ref) for ref in refs if ref.isdigit()]
        if type_ is LinkType.DAY:
            days = [date.fromisoformat(ref) for ref in refs if _is_day(ref)]
            if not days:
                return []
            return self._rows(
                type_,
                self._select(type_)
                .where(
                    AgendaDay.user_id == user_id,
                    AgendaDay.day.in_(days),
                    *criteria,
                )
                .order_by(AgendaDay.day.desc()),
            )
        if not ids:
            return []
        return self._rows(
            type_,
            self._select(type_)
            .where(
                _id_column(type_).in_(ids),
                _owner_column(type_) == user_id,
                *criteria,
            )
            .order_by(_updated_column(type_).desc()),
        )

    def relations_between(self, item_ids: list[int]) -> list[tuple[int, int]]:
        if len(item_ids) < 2:
            return []
        rows = self.session.execute(
            select(KnowledgeRelation.source_id, KnowledgeRelation.target_id)
            .where(
                KnowledgeRelation.source_id.in_(item_ids),
                KnowledgeRelation.target_id.in_(item_ids),
            )
            .order_by(KnowledgeRelation.id)
        ).all()
        return [(source, target) for source, target in rows]

    def goal_links_between(
        self, item_ids: list[int], goal_ids: list[int]
    ) -> list[tuple[int, int]]:
        if not item_ids or not goal_ids:
            return []
        rows = self.session.execute(
            select(KnowledgeGoalLink.item_id, KnowledgeGoalLink.goal_id)
            .where(
                KnowledgeGoalLink.item_id.in_(item_ids),
                KnowledgeGoalLink.goal_id.in_(goal_ids),
            )
            .order_by(KnowledgeGoalLink.id)
        ).all()
        return [(item_id, goal_id) for item_id, goal_id in rows]

    def links(self, user_id: int, limit: int) -> list[EntityLink]:
        return list(
            self.session.scalars(
                select(EntityLink)
                .where(EntityLink.user_id == user_id)
                .order_by(EntityLink.id)
                .limit(limit)
            ).all()
        )

    def link_exists(
        self,
        user_id: int,
        source_type: LinkType,
        source_ref: str,
        target_type: LinkType,
        target_ref: str,
    ) -> bool:
        found = self.session.scalar(
            select(EntityLink.id).where(
                EntityLink.user_id == user_id,
                EntityLink.source_type == source_type,
                EntityLink.source_ref == source_ref,
                EntityLink.target_type == target_type,
                EntityLink.target_ref == target_ref,
            )
        )
        return found is not None

    def add(self, link: EntityLink) -> None:
        self.session.add(link)

    def remove_link(
        self,
        user_id: int,
        source_type: LinkType,
        source_ref: str,
        target_type: LinkType,
        target_ref: str,
    ) -> bool:
        link = self.session.scalar(
            select(EntityLink).where(
                EntityLink.user_id == user_id,
                EntityLink.source_type == source_type,
                EntityLink.source_ref == source_ref,
                EntityLink.target_type == target_type,
                EntityLink.target_ref == target_ref,
            )
        )
        if link is None:
            return False
        self.session.delete(link)
        return True

    def remove_links_for(
        self, user_id: int, type_: LinkType, ref: str
    ) -> None:
        """Descarta as ligações do registro excluído (a tabela não tem FK)."""
        links = self.session.scalars(
            select(EntityLink).where(
                EntityLink.user_id == user_id,
                or_(
                    (EntityLink.source_type == type_)
                    & (EntityLink.source_ref == ref),
                    (EntityLink.target_type == type_)
                    & (EntityLink.target_ref == ref),
                ),
            )
        ).all()
        for link in links:
            self.session.delete(link)

    # -- montagem das consultas ------------------------------------------

    def _query(
        self, type_: LinkType, user_id: int, criteria: list, limit: int
    ) -> list[LifeEntityRow]:
        query = self._select(type_).where(
            _owner_column(type_) == user_id,
            *criteria,
        )
        if type_ is LinkType.GOAL:
            query = query.where(Goal.archived_at.is_(None))
        return self._rows(
            type_,
            query.order_by(_updated_column(type_).desc(), _id_column(type_).desc())
            .limit(limit),
        )

    @staticmethod
    def _select(type_: LinkType):
        if type_ is LinkType.KNOWLEDGE:
            return select(
                KnowledgeItem.id,
                KnowledgeItem.title,
                KnowledgeItem.sensitivity,
                KnowledgeItem.updated_at,
                null().label("day"),
            )
        if type_ is LinkType.GOAL:
            return select(
                Goal.id,
                Goal.title,
                Goal.sensitivity,
                Goal.updated_at,
                null().label("day"),
            )
        if type_ is LinkType.NOTE:
            return select(
                Note.id,
                Note.title,
                Note.sensitivity,
                Note.updated_at,
                null().label("day"),
            )
        if type_ is LinkType.ACTIVITY:
            return select(
                AgendaActivity.id,
                AgendaActivity.title,
                AgendaActivity.sensitivity,
                AgendaActivity.updated_at,
                AgendaActivity.day,
            )
        return select(
            AgendaDay.day,
            null().label("title"),
            AgendaDay.sensitivity,
            AgendaDay.updated_at,
            AgendaDay.day,
        )

    def _rows(self, type_: LinkType, query) -> list[LifeEntityRow]:
        rows = self.session.execute(query).all()
        entities: list[LifeEntityRow] = []
        for row in rows:
            if type_ is LinkType.DAY:
                entities.append(
                    LifeEntityRow(
                        type=type_,
                        ref=row.day.isoformat(),
                        title=None,
                        day=row.day,
                        sensitivity=row.sensitivity,
                        updated_at=row.updated_at,
                    )
                )
                continue
            entities.append(
                LifeEntityRow(
                    type=type_,
                    ref=str(row.id),
                    title=row.title,
                    day=row.day,
                    sensitivity=row.sensitivity,
                    updated_at=row.updated_at,
                )
            )
        return entities


def _id_column(type_: LinkType):
    return {
        LinkType.KNOWLEDGE: KnowledgeItem.id,
        LinkType.GOAL: Goal.id,
        LinkType.NOTE: Note.id,
        LinkType.ACTIVITY: AgendaActivity.id,
        LinkType.DAY: AgendaDay.id,
    }[type_]


def _owner_column(type_: LinkType):
    return {
        LinkType.KNOWLEDGE: KnowledgeItem.user_id,
        LinkType.GOAL: Goal.user_id,
        LinkType.NOTE: Note.user_id,
        LinkType.ACTIVITY: AgendaActivity.user_id,
        LinkType.DAY: AgendaDay.user_id,
    }[type_]


def _updated_column(type_: LinkType):
    return {
        LinkType.KNOWLEDGE: KnowledgeItem.updated_at,
        LinkType.GOAL: Goal.updated_at,
        LinkType.NOTE: Note.updated_at,
        LinkType.ACTIVITY: AgendaActivity.updated_at,
        LinkType.DAY: AgendaDay.updated_at,
    }[type_]


def _is_day(ref: str) -> bool:
    try:
        date.fromisoformat(ref)
    except ValueError:
        return False
    return True
