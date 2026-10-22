from collections.abc import Callable

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from atena_pattern.core.access import Actor
from atena_pattern.core.database import get_db
from atena_pattern.core.errors import AppError
from atena_pattern.core.security import decode_access_token, is_secret_token
from atena_pattern.models.role import Role
from atena_pattern.models.user import User
from atena_pattern.repositories.user_repository import UserRepository
from atena_pattern.services.secret_service import SecretService

bearer_scheme = HTTPBearer(auto_error=False)


def get_actor(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: Session = Depends(get_db),
) -> Actor:
    """Identifica quem chama: sessão do dono ou uma secret da conta.

    Os dois usam o mesmo header `Authorization: Bearer`. O prefixo do token
    decide o caminho: token de secret começa com `mds_`, sessão é um JWT.
    """
    if credentials is None:
        raise AppError(
            code="UNAUTHORIZED",
            message="Faça login para continuar.",
            status_code=401,
        )

    token = credentials.credentials
    if is_secret_token(token):
        secret = SecretService(session).authenticate(token)
        return Actor(user_id=secret.user_id, secret=secret)

    return Actor(user_id=decode_access_token(token))


def get_current_user(
    actor: Actor = Depends(get_actor),
    session: Session = Depends(get_db),
) -> User:
    """Usuário da sessão. Endpoints de administração não aceitam secret."""
    if not actor.is_session:
        raise AppError(
            code="SESSION_REQUIRED",
            message="Este recurso exige a sessão do dono da conta.",
            status_code=403,
        )

    user = UserRepository(session).get_by_id(actor.user_id)
    if user is None:
        raise AppError(
            code="UNAUTHORIZED",
            message="Sessão inválida. Faça login novamente.",
            status_code=401,
        )

    return user


def require_roles(*allowed_roles: Role) -> Callable[..., User]:
    def dependency(user: User = Depends(get_current_user)) -> User:
        if user.role not in allowed_roles:
            raise AppError(
                code="FORBIDDEN",
                message="Você não tem permissão para executar esta ação.",
                status_code=403,
            )
        return user

    return dependency
