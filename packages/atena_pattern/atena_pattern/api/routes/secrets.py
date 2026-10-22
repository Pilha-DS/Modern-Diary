from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from atena_pattern.api.deps import get_current_user
from atena_pattern.core.database import get_db
from atena_pattern.core.responses import api_response
from atena_pattern.models.api_secret import ApiSecret
from atena_pattern.models.user import User
from atena_pattern.schemas.pagination import PageParams, pagination_meta
from atena_pattern.schemas.secret import (
    SecretAuditResponse,
    SecretCreateRequest,
    SecretCreatedResponse,
    SecretResponse,
    SecretUpdateRequest,
)
from atena_pattern.services.secret_service import SecretService

router = APIRouter(prefix="/secrets", tags=["secrets"])


@router.get("", summary="Lista as credenciais da conta (sem o token)")
def list_secrets(
    request: Request,
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    secrets, total = SecretService(session).list_page(
        user.id,
        offset=page.offset,
        limit=page.per_page,
    )
    return api_response(
        request,
        code="SECRETS_LISTED",
        data=[
            SecretResponse.from_model(secret).model_dump(mode="json")
            for secret in secrets
        ],
        meta=pagination_meta(page.page, page.per_page, total),
    )


@router.post(
    "",
    status_code=201,
    summary="Cria uma credencial e devolve o token uma única vez",
)
def create_secret(
    payload: SecretCreateRequest,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    secret, token = SecretService(session).create(
        user.id,
        name=payload.name,
        permissions=payload.permissions,
    )
    return api_response(
        request,
        code="SECRET_CREATED",
        data=_created_payload(secret, token),
        message="Credencial criada. Guarde o token: ele não será mostrado novamente.",
        status_code=201,
    )


@router.get("/{secret_id}", summary="Detalha uma credencial e suas permissões")
def get_secret(
    secret_id: int,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    secret = SecretService(session).get(user.id, secret_id)
    return api_response(
        request,
        code="SECRET_RETRIEVED",
        data=SecretResponse.from_model(secret).model_dump(mode="json"),
    )


@router.patch(
    "/{secret_id}",
    summary="Renomeia a credencial e/ou substitui as permissões",
)
def update_secret(
    secret_id: int,
    payload: SecretUpdateRequest,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    secret = SecretService(session).update(
        user.id,
        secret_id,
        name=payload.name,
        permissions=payload.permissions,
    )
    return api_response(
        request,
        code="SECRET_UPDATED",
        data=SecretResponse.from_model(secret).model_dump(mode="json"),
        message="Credencial atualizada com sucesso.",
    )


@router.post("/{secret_id}/rotate", summary="Troca o token e invalida o anterior")
def rotate_secret(
    secret_id: int,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    secret, token = SecretService(session).rotate(user.id, secret_id)
    return api_response(
        request,
        code="SECRET_TOKEN_ROTATED",
        data=_created_payload(secret, token),
        message="Token trocado. O token anterior não vale mais.",
    )


@router.delete("/{secret_id}", summary="Revoga a credencial e invalida o token")
def revoke_secret(
    secret_id: int,
    request: Request,
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    secret = SecretService(session).revoke(user.id, secret_id)
    return api_response(
        request,
        code="SECRET_REVOKED",
        data=SecretResponse.from_model(secret).model_dump(mode="json"),
        message="Credencial revogada. O token não vale mais.",
    )


@router.get(
    "/{secret_id}/audit",
    summary="Lista as decisões de acesso registradas para a credencial",
)
def list_secret_audit(
    secret_id: int,
    request: Request,
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    entries, total = SecretService(session).audit_page(
        user.id,
        secret_id,
        offset=page.offset,
        limit=page.per_page,
    )
    return api_response(
        request,
        code="SECRET_AUDIT_LISTED",
        data=[
            SecretAuditResponse.from_model(entry).model_dump(mode="json")
            for entry in entries
        ],
        meta=pagination_meta(page.page, page.per_page, total),
    )


def _created_payload(secret: ApiSecret, token: str) -> dict:
    return SecretCreatedResponse(
        **SecretResponse.from_model(secret).model_dump(),
        token=token,
    ).model_dump(mode="json")
