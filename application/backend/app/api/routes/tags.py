from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.database import get_db
from app.core.responses import api_response
from app.models.user import User
from app.schemas.pagination import PageParams, pagination_meta
from app.schemas.tag import TagCreateRequest, TagResponse, TagUpdateRequest
from app.services.tag_service import TagService

router = APIRouter(prefix="/tags", tags=["tags"])


@router.get("", summary="Lista as tags paginadas, com a quantidade de usos")
def list_tags(
    request: Request,
    q: str | None = Query(default=None, max_length=40, description="Busca por nome"),
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    service = TagService(session)
    query = (q or "").strip() or None
    tags, counts, total = service.list_page(
        user.id,
        query=query,
        offset=page.offset,
        limit=page.per_page,
    )
    return api_response(
        request,
        code="TAGS_LISTED",
        data=[
            TagResponse.from_model(tag, counts.get(tag.id, 0)).model_dump(
                mode="json"
            )
            for tag in tags
        ],
        meta=pagination_meta(page.page, page.per_page, total),
    )


@router.post("", status_code=201, summary="Cria uma tag")
def create_tag(
    payload: TagCreateRequest,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    tag = TagService(session).create_tag(
        user.id,
        name=payload.name,
        color=payload.color,
        description=payload.description,
    )
    return api_response(
        request,
        code="TAG_CREATED",
        data=TagResponse.from_model(tag, 0).model_dump(mode="json"),
        message="Tag criada com sucesso.",
        status_code=201,
    )


@router.patch("/{tag_id}", summary="Atualiza uma tag")
def update_tag(
    tag_id: int,
    payload: TagUpdateRequest,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    service = TagService(session)
    tag = service.update_tag(
        user.id,
        tag_id,
        name=payload.name,
        color=payload.color,
        description=payload.description,
        change_description="description" in payload.model_fields_set,
    )
    return api_response(
        request,
        code="TAG_UPDATED",
        data=TagResponse.from_model(
            tag,
            service.usage_count(tag.id),
        ).model_dump(mode="json"),
        message="Tag atualizada com sucesso.",
    )


@router.delete("/{tag_id}", summary="Exclui uma tag e suas ligações")
def delete_tag(
    tag_id: int,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    TagService(session).delete_tag(user.id, tag_id)
    return api_response(
        request,
        code="TAG_DELETED",
        data={"id": tag_id},
        message="Tag excluída com sucesso.",
    )


@router.get("/{tag_id}/usages", summary="Lista onde a tag está sendo usada")
def list_usages(
    tag_id: int,
    request: Request,
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    usages, total = TagService(session).usages(
        user.id,
        tag_id,
        offset=page.offset,
        limit=page.per_page,
    )
    return api_response(
        request,
        code="TAG_USAGES_LISTED",
        data=[usage.model_dump(mode="json") for usage in usages],
        meta=pagination_meta(page.page, page.per_page, total),
    )
