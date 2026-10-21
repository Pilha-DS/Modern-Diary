from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.responses import api_response
from app.models.user import User
from app.schemas.country import MAX_SEARCH_LENGTH, CountryResponse
from app.schemas.pagination import PageParams, pagination_meta
from app.services.country_service import CountryService

router = APIRouter(prefix="/countries", tags=["countries"])


@router.get("", summary="Lista os países da tabela de referência")
def list_countries(
    request: Request,
    q: str | None = Query(
        default=None,
        max_length=MAX_SEARCH_LENGTH,
        description="Busca por nome, nome oficial ou código ISO",
    ),
    continent: str | None = Query(
        default=None,
        max_length=24,
        description="Filtra por continente, como na resposta",
    ),
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    query = (q or "").strip() or None
    countries, total = CountryService(session).list_countries(
        offset=page.offset,
        limit=page.per_page,
        query=query,
        continent=(continent or "").strip() or None,
    )
    return api_response(
        request,
        code="COUNTRIES_LISTED",
        data=[
            CountryResponse.model_validate(country).model_dump(mode="json")
            for country in countries
        ],
        meta=pagination_meta(page.page, page.per_page, total),
    )
