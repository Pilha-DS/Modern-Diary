from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from atena_pattern.api.deps import get_current_user
from atena_pattern.core.database import get_db
from atena_pattern.core.responses import api_response
from atena_pattern.models.user import User
from atena_pattern.schemas.auth import AuthData
from atena_pattern.schemas.envelope import Envelope
from atena_pattern.schemas.user import LoginRequest, RegisterRequest, UserResponse
from atena_pattern.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])


def auth_data(user: User, access_token: str, expires_in: int) -> dict:
    return AuthData(
        access_token=access_token,
        expires_in=expires_in,
        user=UserResponse.model_validate(user),
    ).model_dump(mode="json")


@router.post(
    "/register",
    response_model=Envelope[AuthData],
    status_code=201,
    summary="Cadastra um usuário; o primeiro cadastro vira ADMIN",
)
def register(
    payload: RegisterRequest,
    request: Request,
    session: Session = Depends(get_db),
):
    user, access_token, expires_in = AuthService(session).register(
        username=payload.username,
        password=payload.password,
    )
    return api_response(
        request,
        code="USER_REGISTERED",
        data=auth_data(user, access_token, expires_in),
        message="Cadastro realizado com sucesso.",
        status_code=201,
    )


@router.post(
    "/login",
    response_model=Envelope[AuthData],
    summary="Autentica e devolve o token de acesso",
)
def login(
    payload: LoginRequest,
    request: Request,
    session: Session = Depends(get_db),
):
    user, access_token, expires_in = AuthService(session).login(
        username=payload.username,
        password=payload.password,
    )
    return api_response(
        request,
        code="AUTHENTICATED",
        data=auth_data(user, access_token, expires_in),
        message="Login realizado com sucesso.",
    )


@router.get(
    "/me",
    response_model=Envelope[UserResponse],
    summary="Devolve o usuário autenticado",
)
def me(request: Request, user: User = Depends(get_current_user)):
    return api_response(
        request,
        code="USER_PROFILE",
        data=UserResponse.model_validate(user).model_dump(mode="json"),
    )
