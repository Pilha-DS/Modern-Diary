from datetime import timedelta

from sqlalchemy.orm import Session

from atena_pattern.core.access import areas
from atena_pattern.core.errors import AppError
from atena_pattern.core.security import create_secret_token, hash_secret_token
from atena_pattern.models.api_secret import (
    ApiSecret,
    SecretAreaPermission,
    SecretAuditLog,
)
from atena_pattern.models.user import utc_now
from atena_pattern.repositories.api_secret_repository import ApiSecretRepository
from atena_pattern.schemas.secret import (
    MAX_SECRETS_PER_USER,
    SecretPermissionRequest,
)

#: Evita gravar `last_used_at` a cada requisição de leitura da mesma secret.
LAST_USED_WRITE_INTERVAL = timedelta(minutes=5)


class SecretService:
    """Cria, administra e valida as credenciais de integração."""

    def __init__(self, session: Session) -> None:
        self.session = session
        self.secrets = ApiSecretRepository(session)

    def list_page(
        self, user_id: int, *, offset: int, limit: int
    ) -> tuple[list[ApiSecret], int]:
        return self.secrets.list_page(user_id, offset, limit)

    def get(self, user_id: int, secret_id: int) -> ApiSecret:
        return self._get_or_fail(user_id, secret_id)

    def create(
        self,
        user_id: int,
        *,
        name: str,
        permissions: dict[str, SecretPermissionRequest],
    ) -> tuple[ApiSecret, str]:
        if self.secrets.count(user_id) >= MAX_SECRETS_PER_USER:
            raise AppError(
                code="SECRET_LIMIT",
                message="Você já atingiu o limite de credenciais.",
                status_code=409,
            )
        self._ensure_known_areas(permissions)
        self._ensure_name_is_free(user_id, name)

        token, token_hash, token_hint = create_secret_token()
        secret = ApiSecret(
            user_id=user_id,
            name=name,
            token_hash=token_hash,
            token_hint=token_hint,
        )
        secret.permissions = _build_permissions(permissions)
        self.secrets.add(secret)
        self.session.commit()
        return secret, token

    def update(
        self,
        user_id: int,
        secret_id: int,
        *,
        name: str | None = None,
        permissions: dict[str, SecretPermissionRequest] | None = None,
    ) -> ApiSecret:
        secret = self._get_or_fail(user_id, secret_id)
        self._ensure_active(secret)

        if name is not None and name != secret.name:
            self._ensure_name_is_free(user_id, name, exclude_id=secret.id)
            secret.name = name
        if permissions is not None:
            self._ensure_known_areas(permissions)
            _apply_permissions(secret, permissions)
            secret.updated_at = utc_now()

        self.session.commit()
        return secret

    def rotate(self, user_id: int, secret_id: int) -> tuple[ApiSecret, str]:
        """Troca o token: o anterior deixa de valer imediatamente."""
        secret = self._get_or_fail(user_id, secret_id)
        self._ensure_active(secret)

        token, token_hash, token_hint = create_secret_token()
        secret.token_hash = token_hash
        secret.token_hint = token_hint
        self.session.commit()
        return secret, token

    def revoke(self, user_id: int, secret_id: int) -> ApiSecret:
        """Revoga a credencial. O registro e a auditoria continuam guardados."""
        secret = self._get_or_fail(user_id, secret_id)
        if secret.is_active:
            secret.revoked_at = utc_now()
            self.session.commit()
        return secret

    def audit_page(
        self, user_id: int, secret_id: int, *, offset: int, limit: int
    ) -> tuple[list[SecretAuditLog], int]:
        self._get_or_fail(user_id, secret_id)
        return self.secrets.audit_page(user_id, secret_id, offset, limit)

    def authenticate(self, token: str) -> ApiSecret:
        """Resolve o token enviado na requisição. Token nunca é comparado cru."""
        secret = self.secrets.get_by_token_hash(hash_secret_token(token))
        if secret is None:
            raise AppError(
                code="INVALID_SECRET",
                message="Credencial inválida.",
                status_code=401,
            )
        if not secret.is_active:
            raise AppError(
                code="SECRET_REVOKED",
                message="Esta credencial foi revogada.",
                status_code=401,
            )

        now = utc_now()
        if secret.last_used_at is None or (
            now - secret.last_used_at > LAST_USED_WRITE_INTERVAL
        ):
            secret.last_used_at = now
            self.session.commit()
        return secret

    @staticmethod
    def _ensure_known_areas(permissions: dict[str, SecretPermissionRequest]) -> None:
        for area in permissions:
            if not areas.has(area):
                raise AppError(
                    code="AREA_UNKNOWN",
                    message=f"A área '{area}' não existe neste sistema.",
                    status_code=422,
                )

    def _ensure_name_is_free(
        self, user_id: int, name: str, exclude_id: int | None = None
    ) -> None:
        if self.secrets.name_exists(user_id, name, exclude_id=exclude_id):
            raise AppError(
                code="SECRET_NAME_EXISTS",
                message="Já existe uma credencial com esse nome.",
                status_code=409,
            )

    @staticmethod
    def _ensure_active(secret: ApiSecret) -> None:
        if not secret.is_active:
            raise AppError(
                code="SECRET_REVOKED",
                message="Esta credencial foi revogada. Crie uma nova.",
                status_code=409,
            )

    def _get_or_fail(self, user_id: int, secret_id: int) -> ApiSecret:
        secret = self.secrets.get(user_id, secret_id)
        if secret is None:
            raise AppError(
                code="SECRET_NOT_FOUND",
                message="Credencial não encontrada.",
                status_code=404,
            )
        return secret


def _build_permissions(
    permissions: dict[str, SecretPermissionRequest],
) -> list[SecretAreaPermission]:
    return [
        SecretAreaPermission(
            area=area,
            read_level=permission.read,
            can_create=permission.create,
            can_write=permission.write,
        )
        for area, permission in permissions.items()
    ]


def _apply_permissions(
    secret: ApiSecret,
    permissions: dict[str, SecretPermissionRequest],
) -> None:
    """Atualiza no lugar e troca só o que mudou.

    Recriar todas as linhas colidiria com a unicidade `(secret_id, area)` quando a
    área já existia; atualizar mantém o mesmo identificador e a auditoria limpa.
    """
    existing = {permission.area: permission for permission in secret.permissions}
    for area, requested in permissions.items():
        current = existing.pop(area, None)
        if current is None:
            secret.permissions.append(
                SecretAreaPermission(
                    area=area,
                    read_level=requested.read,
                    can_create=requested.create,
                    can_write=requested.write,
                )
            )
            continue
        current.read_level = requested.read
        current.can_create = requested.create
        current.can_write = requested.write

    for removed in existing.values():
        secret.permissions.remove(removed)
