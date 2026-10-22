from datetime import date

from sqlalchemy.orm import Session

from atena_pattern.core.access import AccessGuard, Actor
from app.models.agenda import AgendaActivity, AgendaNote
from app.core.areas import Area
from app.models.goal import Goal
from app.models.knowledge import KnowledgeItem
from app.models.note import Note
from atena_pattern.models.sensitivity import Sensitivity
from app.repositories.search_repository import SearchRepository
from app.schemas.search import SearchResultResponse, SearchType

#: Área e coluna de nível de cada tipo pesquisado.
TYPE_ACCESS = {
    SearchType.KNOWLEDGE: (Area.KNOWLEDGE, KnowledgeItem.sensitivity),
    SearchType.GOAL: (Area.GOAL, Goal.sensitivity),
    SearchType.NOTE: (Area.NOTE, Note.sensitivity),
    SearchType.AGENDA_NOTE: (Area.DAY, AgendaNote.sensitivity),
    SearchType.ACTIVITY: (Area.ACTIVITY, AgendaActivity.sensitivity),
}


class SearchService:
    """Pesquisa em todas as áreas, respeitando o acesso de quem lê."""

    def __init__(self, session: Session, actor: Actor) -> None:
        self.actor = actor
        self.access = AccessGuard(session, actor)
        self.repository = SearchRepository(session)

    def search(
        self,
        *,
        term: str,
        types: list[SearchType],
        tag_id: int | None,
        level: Sensitivity | None,
        from_day: date | None,
        to_day: date | None,
        offset: int,
        limit: int,
    ) -> tuple[list[SearchResultResponse], int]:
        criteria = self._criteria()
        rows, total = self.repository.search(
            user_id=self.actor.user_id,
            term=term,
            types=[search_type.value for search_type in types],
            criteria=criteria,
            tag_id=tag_id,
            level=level,
            from_day=from_day,
            to_day=to_day,
            offset=offset,
            limit=limit,
        )
        return [self._result(row) for row in rows], total

    def _criteria(self) -> dict[str, list]:
        """Áreas que a credencial enxerga, cada uma com o filtro de nível."""
        criteria: dict[str, list] = {}
        for search_type, (area, column) in TYPE_ACCESS.items():
            visible = self.access.optional_visible_on(area, column)
            if visible is not None:
                criteria[search_type.value] = visible
        return criteria

    @staticmethod
    def _result(row: tuple) -> SearchResultResponse:
        type_value, ref, title, snippet, day, sensitivity, updated_at = row
        return SearchResultResponse(
            type=SearchType(type_value),
            ref=ref,
            title=title,
            snippet=snippet,
            day=day,
            sensitivity=Sensitivity(sensitivity).api_value,
            updated_at=updated_at,
        )
