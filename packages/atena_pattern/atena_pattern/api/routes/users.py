from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from atena_pattern.api.deps import require_roles
from atena_pattern.core.database import get_db
from atena_pattern.core.responses import api_response
from atena_pattern.models.role import Role
from atena_pattern.models.user import User
from atena_pattern.schemas.envelope import Envelope
from atena_pattern.schemas.pagination import PageParams, pagination_meta
from atena_pattern.schemas.user import UpdateRoleRequest, UserResponse
from atena_pattern.services.user_service import UserService

router = APIRouter(prefix="/users", tags=["users"])

admin_only = require_roles(Role.ADMIN)


@router.get(
    "",
    response_model=Envelope[list[UserResponse]],
    summary="Lista usuários paginados (somente ADMIN)",
)
def list_users(
    request: Request,
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    users, total = UserService(session).list_page(offset=page.offset, limit=page.per_page)
    return api_response(
        request,
        code="USERS_LISTED",
        data=[UserResponse.model_validate(user).model_dump(mode="json") for user in users],
        meta=pagination_meta(page.page, page.per_page, total),
    )


@router.patch(
    "/{user_id}/role",
    response_model=Envelope[UserResponse],
    summary="Altera a role entre MODERATOR e USER (somente ADMIN)",
)
def update_user_role(
    user_id: int,
    payload: UpdateRoleRequest,
    request: Request,
    session: Session = Depends(get_db),
    _: User = Depends(admin_only),
):
    updated_user = UserService(session).update_role(
        target_user_id=user_id,
        role=payload.parsed_role(),
    )
    return api_response(
        request,
        code="USER_ROLE_UPDATED",
        data=UserResponse.model_validate(updated_user).model_dump(mode="json"),
        message="Role atualizada com sucesso.",
    )
