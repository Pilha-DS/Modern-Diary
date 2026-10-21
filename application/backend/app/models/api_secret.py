from datetime import datetime
from enum import StrEnum

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.area import Area
from app.models.sensitivity import Sensitivity, SensitivityType
from app.models.user import utc_now


class AuditAction(StrEnum):
    READ = "READ"
    CREATE = "CREATE"
    UPDATE = "UPDATE"
    DELETE = "DELETE"


class AuditResult(StrEnum):
    ALLOWED = "ALLOWED"
    DENIED = "DENIED"


class ApiSecret(Base):
    """Credencial de uma integração, ligada a um único usuário.

    O token em texto puro só aparece na criação e na rotação; o banco guarda
    apenas o hash SHA-256, o suficiente para validar cada requisição.
    """

    __tablename__ = "api_secrets"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_api_secrets_user_name"),
        Index("ix_api_secrets_user_created", "user_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(60), nullable=False)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    token_hint: Mapped[str] = mapped_column(String(12), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        onupdate=utc_now,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    permissions: Mapped[list["SecretAreaPermission"]] = relationship(
        back_populates="secret",
        cascade="all, delete-orphan",
        order_by="SecretAreaPermission.area",
        lazy="selectin",
    )

    @property
    def is_active(self) -> bool:
        return self.revoked_at is None

    def permission_for(self, area: Area) -> "SecretAreaPermission | None":
        for permission in self.permissions:
            if permission.area is area:
                return permission
        return None


class SecretAreaPermission(Base):
    """Permissões de uma secret em uma área: leitura, criação e escrita."""

    __tablename__ = "secret_area_permissions"
    __table_args__ = (
        UniqueConstraint("secret_id", "area", name="uq_secret_area_permissions_area"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    secret_id: Mapped[int] = mapped_column(
        ForeignKey("api_secrets.id", ondelete="CASCADE"),
        nullable=False,
    )
    area: Mapped[Area] = mapped_column(Enum(Area, name="secret_area"), nullable=False)
    read_level: Mapped[Sensitivity] = mapped_column(
        SensitivityType(),
        nullable=False,
    )
    can_create: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("0"),
    )
    can_write: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("0"),
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        onupdate=utc_now,
        server_default=text("CURRENT_TIMESTAMP"),
    )
    secret: Mapped[ApiSecret] = relationship(back_populates="permissions")


class SecretAuditLog(Base):
    """Decisão de acesso tomada para uma secret, para auditoria."""

    __tablename__ = "secret_audit_logs"
    __table_args__ = (
        Index("ix_secret_audit_logs_secret_created", "secret_id", "created_at"),
        Index("ix_secret_audit_logs_user_created", "user_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    secret_id: Mapped[int] = mapped_column(
        ForeignKey("api_secrets.id", ondelete="CASCADE"),
        nullable=False,
    )
    area: Mapped[Area] = mapped_column(Enum(Area, name="secret_area"), nullable=False)
    action: Mapped[AuditAction] = mapped_column(
        Enum(AuditAction, name="secret_audit_action"),
        nullable=False,
    )
    result: Mapped[AuditResult] = mapped_column(
        Enum(AuditResult, name="secret_audit_result"),
        nullable=False,
    )
    target_type: Mapped[str | None] = mapped_column(String(40), nullable=True)
    target_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    request_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )
