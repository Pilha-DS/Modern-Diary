from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from atena_pattern.models.api_secret import ApiSecret, SecretAuditLog
from atena_pattern.schemas.sensitivity import ReadLevel

MAX_SECRET_NAME_LENGTH = 60
MAX_SECRETS_PER_USER = 50


class SecretPermissionRequest(BaseModel):
    """Permissões de uma área: nível lido, criar e alterar."""

    read: ReadLevel
    create: bool = False
    write: bool = False


class SecretCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=MAX_SECRET_NAME_LENGTH)
    permissions: dict[str, SecretPermissionRequest] = Field(min_length=1)

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("nome vazio")
        return stripped


class SecretUpdateRequest(BaseModel):
    """Campo ausente não muda; `permissions` substitui a configuração."""

    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=MAX_SECRET_NAME_LENGTH,
    )
    permissions: dict[str, SecretPermissionRequest] | None = None

    @field_validator("name")
    @classmethod
    def strip_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        stripped = value.strip()
        if not stripped:
            raise ValueError("nome vazio")
        return stripped


class SecretPermissionResponse(BaseModel):
    read: str
    create: bool
    write: bool


class SecretResponse(BaseModel):
    id: int
    name: str
    token_hint: str
    is_active: bool
    permissions: dict[str, SecretPermissionResponse]
    created_at: datetime
    updated_at: datetime
    last_used_at: datetime | None

    @classmethod
    def from_model(cls, secret: ApiSecret) -> "SecretResponse":
        return cls(
            id=secret.id,
            name=secret.name,
            token_hint=secret.token_hint,
            is_active=secret.is_active,
            permissions={
                permission.area: SecretPermissionResponse(
                    read=permission.read_level.api_value,
                    create=permission.can_create,
                    write=permission.can_write,
                )
                for permission in secret.permissions
            },
            created_at=secret.created_at,
            updated_at=secret.updated_at,
            last_used_at=secret.last_used_at,
        )


class SecretCreatedResponse(SecretResponse):
    """Resposta da criação e da rotação: o token aparece só aqui."""

    token: str


class SecretAuditResponse(BaseModel):
    id: int
    area: str
    action: str
    result: str
    target_type: str | None
    target_id: int | None
    request_id: str | None
    created_at: datetime

    @classmethod
    def from_model(cls, entry: SecretAuditLog) -> "SecretAuditResponse":
        return cls(
            id=entry.id,
            area=entry.area,
            action=entry.action.value,
            result=entry.result.value,
            target_type=entry.target_type,
            target_id=entry.target_id,
            request_id=entry.request_id,
            created_at=entry.created_at,
        )
