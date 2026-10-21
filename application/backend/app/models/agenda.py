from datetime import date, datetime, time
from enum import StrEnum

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    String,
    Text,
    Time,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.sensitivity import Sensitivity, SensitivityType
from app.models.user import utc_now


class Priority(StrEnum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class AgendaDay(Base):
    """Nota do dia, escrita em markdown. Uma linha por usuário e data."""

    __tablename__ = "agenda_days"
    __table_args__ = (
        UniqueConstraint("user_id", "day", name="uq_agenda_days_user_day"),
        Index("ix_agenda_days_user_sensitivity", "user_id", "sensitivity"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    day: Mapped[date] = mapped_column(Date, nullable=False)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    sensitivity: Mapped[Sensitivity] = mapped_column(
        SensitivityType(),
        nullable=False,
        default=Sensitivity.PUBLIC,
        server_default=text("1"),
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


class AgendaActivity(Base):
    """Atividade de um dia, com horário opcional e prioridade."""

    __tablename__ = "agenda_activities"
    __table_args__ = (
        Index("ix_agenda_activities_user_day", "user_id", "day"),
        Index("ix_agenda_activities_user_sensitivity", "user_id", "sensitivity"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    day: Mapped[date] = mapped_column(Date, nullable=False)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    start_time: Mapped[time | None] = mapped_column(Time, nullable=True)
    sensitivity: Mapped[Sensitivity] = mapped_column(
        SensitivityType(),
        nullable=False,
        default=Sensitivity.PUBLIC,
        server_default=text("1"),
    )
    priority: Mapped[Priority] = mapped_column(
        Enum(Priority, name="agenda_priority"),
        nullable=False,
        default=Priority.MEDIUM,
    )
    is_done: Mapped[bool] = mapped_column(
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
