from datetime import date, datetime
from enum import StrEnum

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from atena_pattern.core.database import Base
from atena_pattern.models.sensitivity import Sensitivity, SensitivityType
from atena_pattern.models.user import utc_now


class GoalStatus(StrEnum):
    """Situação da meta. Arquivar é uma marca separada, não um estado."""

    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"


class Goal(Base):
    """Meta do usuário, com etapas opcionais e progresso derivado delas."""

    __tablename__ = "goals"
    __table_args__ = (
        Index("ix_goals_user_status_created", "user_id", "status", "created_at"),
        Index("ix_goals_user_sensitivity", "user_id", "sensitivity"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    due_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    sensitivity: Mapped[Sensitivity] = mapped_column(
        SensitivityType(),
        nullable=False,
        default=Sensitivity.PUBLIC,
        server_default=text("1"),
    )
    status: Mapped[GoalStatus] = mapped_column(
        Enum(GoalStatus, name="goal_status"),
        nullable=False,
        default=GoalStatus.ACTIVE,
    )
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
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
    steps: Mapped[list["GoalStep"]] = relationship(
        back_populates="goal",
        cascade="all, delete-orphan",
        order_by="GoalStep.position, GoalStep.id",
        lazy="selectin",
    )


class GoalStep(Base):
    """Etapa opcional de uma meta. A ordem é a de criação."""

    __tablename__ = "goal_steps"
    __table_args__ = (
        Index("ix_goal_steps_goal_position", "goal_id", "position"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    goal_id: Mapped[int] = mapped_column(
        ForeignKey("goals.id", ondelete="CASCADE"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    is_done: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("0"),
    )
    position: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
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
    goal: Mapped[Goal] = relationship(back_populates="steps")
