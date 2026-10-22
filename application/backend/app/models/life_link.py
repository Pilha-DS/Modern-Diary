from datetime import datetime
from enum import StrEnum

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    Index,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.user import utc_now


class LinkType(StrEnum):
    """Entidade que pode entrar no grafo de vida."""

    KNOWLEDGE = "knowledge"
    GOAL = "goal"
    NOTE = "note"
    ACTIVITY = "activity"
    DAY = "day"


class EntityLink(Base):
    """Ligação manual entre dois registros de qualquer tipo.

    O par é guardado em ordem canônica (tipo e referência ordenados), para a
    ligação A→B e a B→A caírem na mesma linha da restrição única.
    """

    __tablename__ = "entity_links"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "source_type",
            "source_ref",
            "target_type",
            "target_ref",
            name="uq_entity_links_pair",
        ),
        Index("ix_entity_links_user_target", "user_id", "target_type", "target_ref"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    source_type: Mapped[LinkType] = mapped_column(
        Enum(LinkType, name="entity_link_type"),
        nullable=False,
    )
    source_ref: Mapped[str] = mapped_column(String(40), nullable=False)
    target_type: Mapped[LinkType] = mapped_column(
        Enum(LinkType, name="entity_link_type"),
        nullable=False,
    )
    target_ref: Mapped[str] = mapped_column(String(40), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )
