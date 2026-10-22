from datetime import date, datetime
from enum import StrEnum

from sqlalchemy import (
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.user import utc_now


class AuditArea(StrEnum):
    """Área da ação registrada. `Area` guarda só as áreas de secrets."""

    KNOWLEDGE = "knowledge"
    GOAL = "goal"
    NOTE = "note"
    DAY = "day"
    ACTIVITY = "activity"
    TAG = "tag"


class AuditKind(StrEnum):
    CREATE = "CREATE"
    UPDATE = "UPDATE"
    DELETE = "DELETE"
    LINK = "LINK"
    UNLINK = "UNLINK"


class AuditEvent(Base):
    """Ação do usuário em um dia, base do histórico e do grafo da auditoria.

    `source` é o registro principal da ação e `target` o outro lado, quando a
    ação liga duas coisas (conhecimento a conhecimento, meta a conhecimento).
    `day` é o dia local de quem agiu, para a tela agrupar sem depender do fuso.
    """

    __tablename__ = "audit_events"
    __table_args__ = (
        Index("ix_audit_events_user_day_occurred", "user_id", "day", "occurred_at"),
        Index("ix_audit_events_user_occurred", "user_id", "occurred_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    day: Mapped[date] = mapped_column(Date, nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )
    area: Mapped[AuditArea] = mapped_column(
        Enum(AuditArea, name="audit_area"),
        nullable=False,
    )
    kind: Mapped[AuditKind] = mapped_column(
        Enum(AuditKind, name="audit_event_kind"),
        nullable=False,
    )
    source_type: Mapped[str] = mapped_column(String(20), nullable=False)
    source_ref: Mapped[str] = mapped_column(String(40), nullable=False)
    source_label: Mapped[str] = mapped_column(String(160), nullable=False)
    target_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    target_ref: Mapped[str | None] = mapped_column(String(40), nullable=True)
    target_label: Mapped[str | None] = mapped_column(String(160), nullable=True)
