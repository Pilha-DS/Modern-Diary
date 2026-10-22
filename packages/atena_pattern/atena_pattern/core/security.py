import hashlib
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerifyMismatchError

from atena_pattern.core.config import get_settings
from atena_pattern.core.errors import AppError
from atena_pattern.models.role import Role

ALGORITHM = "HS256"
TOKEN_TYPE = "access"
ATTACHMENT_TOKEN_TYPE = "attachment"
ATTACHMENT_TOKEN_MINUTES = 10
SECRET_TOKEN_BYTES = 30
SECRET_TOKEN_HINT_LENGTH = 6

password_hasher = PasswordHasher()
dummy_password_hash = password_hasher.hash("atena-pattern-dummy-password")


def hash_password(password: str) -> str:
    return password_hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return password_hasher.verify(password_hash, password)
    except (VerifyMismatchError, InvalidHashError):
        return False


def create_access_token(user_id: int, role: Role) -> tuple[str, int]:
    settings = get_settings()
    expires_in = settings.access_token_expire_minutes * 60
    issued_at = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "role": role.value,
        "type": TOKEN_TYPE,
        "iat": issued_at,
        "exp": issued_at + timedelta(seconds=expires_in),
    }
    token = jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)
    return token, expires_in


def decode_access_token(token: str) -> int:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError as error:
        raise AppError(
            code="TOKEN_EXPIRED",
            message="Sua sessão expirou. Faça login novamente.",
            status_code=401,
        ) from error
    except jwt.InvalidTokenError as error:
        raise AppError(
            code="INVALID_TOKEN",
            message="Sessão inválida. Faça login novamente.",
            status_code=401,
        ) from error

    if payload.get("type") != TOKEN_TYPE:
        raise AppError(
            code="INVALID_TOKEN",
            message="Sessão inválida. Faça login novamente.",
            status_code=401,
        )

    try:
        return int(payload["sub"])
    except (KeyError, TypeError, ValueError) as error:
        raise AppError(
            code="INVALID_TOKEN",
            message="Sessão inválida. Faça login novamente.",
            status_code=401,
        ) from error


def create_secret_token() -> tuple[str, str, str]:
    """Gera o token de uma secret.

    Devolve `(token, hash, hint)`. O token em texto puro só é mostrado uma vez;
    o banco guarda o hash e o final dele, para o usuário reconhecer a credencial.
    """
    token = get_settings().secret_token_prefix + secrets.token_urlsafe(
        SECRET_TOKEN_BYTES
    )
    return token, hash_secret_token(token), token[-SECRET_TOKEN_HINT_LENGTH:]


def hash_secret_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def is_secret_token(token: str) -> bool:
    return token.startswith(get_settings().secret_token_prefix)


def create_attachment_token(user_id: int, attachment_id: int) -> str:
    """Token curto para abrir um anexo por URL, sem expor o token de sessão."""
    issued_at = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "attachment": attachment_id,
        "type": ATTACHMENT_TOKEN_TYPE,
        "iat": issued_at,
        "exp": issued_at + timedelta(minutes=ATTACHMENT_TOKEN_MINUTES),
    }
    return jwt.encode(payload, get_settings().secret_key, algorithm=ALGORITHM)


def decode_attachment_token(token: str) -> tuple[int, int]:
    try:
        payload = jwt.decode(token, get_settings().secret_key, algorithms=[ALGORITHM])
    except jwt.ExpiredSignatureError as error:
        raise AppError(
            code="ATTACHMENT_LINK_EXPIRED",
            message="O link do anexo expirou. Abra o anexo novamente.",
            status_code=401,
        ) from error
    except jwt.InvalidTokenError as error:
        raise AppError(
            code="INVALID_TOKEN",
            message="Link de anexo inválido.",
            status_code=401,
        ) from error

    if payload.get("type") != ATTACHMENT_TOKEN_TYPE:
        raise AppError(
            code="INVALID_TOKEN",
            message="Link de anexo inválido.",
            status_code=401,
        )

    try:
        return int(payload["sub"]), int(payload["attachment"])
    except (KeyError, TypeError, ValueError) as error:
        raise AppError(
            code="INVALID_TOKEN",
            message="Link de anexo inválido.",
            status_code=401,
        ) from error
