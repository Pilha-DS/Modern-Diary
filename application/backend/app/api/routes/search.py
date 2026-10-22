from datetime import date

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from atena_pattern.api.deps import get_actor
from atena_pattern.core.access import Actor
from atena_pattern.core.database import get_db
from atena_pattern.core.errors import AppError
from atena_pattern.core.responses import api_response
from atena_pattern.models.sensitivity import Sensitivity
from atena_pattern.schemas.pagination import PageParams, pagination_meta
from app.schemas.search import SearchType
from app.services.search_service import SearchService

router = APIRouter(prefix="/search", tags=["search"])

MAX_TERM_LENGTH = 120


def _types(raw: str | None) -> list[SearchType]:
    if not raw:
        return list(SearchType)
    selected: list[SearchType] = []
    for value in raw.split(","):
        try:
            search_type = SearchType(value.strip())
        except ValueError as error:
            raise AppError(
                code="SEARCH_INVALID_TYPE",
                message="Tipo de registro desconhecido no filtro.",
                status_code=422,
            ) from error
        if search_type not in selected:
            selected.append(search_type)
    return selected


def _sensitivity(raw: str | None) -> Sensitivity | None:
    if not raw:
        return None
    try:
        level = Sensitivity.from_api(raw)
    except ValueError as error:
        raise AppError(
            code="SEARCH_INVALID_SENSITIVITY",
            message="Nível de sensibilidade desconhecido no filtro.",
            status_code=422,
        ) from error
    return None if level is Sensitivity.ALL else level


@router.get("", summary="Pesquisa em todas as áreas")
def search(
    request: Request,
    q: str = Query(
        min_length=1,
        max_length=MAX_TERM_LENGTH,
        description="Texto procurado no título e no conteúdo markdown",
    ),
    types: str | None = Query(
        default=None,
        description=(
            "Tipos separados por vírgula: "
            "knowledge,goal,note,agenda_note,activity"
        ),
    ),
    from_day: date | None = Query(default=None, alias="from"),
    to_day: date | None = Query(default=None, alias="to"),
    tag_id: int | None = Query(default=None),
    sensitivity: str | None = Query(default=None),
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    term = " ".join(q.split())
    results = []
    total = 0
    if term:
        results, total = SearchService(session, actor).search(
            term=term,
            types=_types(types),
            tag_id=tag_id,
            level=_sensitivity(sensitivity),
            from_day=from_day,
            to_day=to_day,
            offset=page.offset,
            limit=page.per_page,
        )
    return api_response(
        request,
        code="SEARCH_RESULTS",
        data=[result.model_dump(mode="json") for result in results],
        meta=pagination_meta(page.page, page.per_page, total),
    )
