from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Index,
    Integer,
    JSON,
    LargeBinary,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.mysql import LONGBLOB
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base
from app.models.sensitivity import Sensitivity, SensitivityType
from app.models.user import utc_now


class KnowledgeItem(Base):
    """Conhecimento do usuário: texto livre, links externos e anexos.

    As conexões com outros conhecimentos ficam em `KnowledgeRelation`.
    """

    __tablename__ = "knowledge_items"
    __table_args__ = (
        Index("ix_knowledge_items_user_updated", "user_id", "updated_at"),
        Index("ix_knowledge_items_user_sensitivity", "user_id", "sensitivity"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    links: Mapped[list[dict] | None] = mapped_column(JSON, nullable=True)
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


class KnowledgeRelation(Base):
    """Aresta entre dois conhecimentos do mesmo usuário."""

    __tablename__ = "knowledge_relations"
    __table_args__ = (
        UniqueConstraint("source_id", "target_id", name="uq_knowledge_relations_pair"),
        Index("ix_knowledge_relations_target", "target_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    source_id: Mapped[int] = mapped_column(
        ForeignKey("knowledge_items.id", ondelete="CASCADE"),
        nullable=False,
    )
    target_id: Mapped[int] = mapped_column(
        ForeignKey("knowledge_items.id", ondelete="CASCADE"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )


class KnowledgeGoalLink(Base):
    """Ligação de um conhecimento com uma meta do mesmo usuário."""

    __tablename__ = "knowledge_goal_links"
    __table_args__ = (
        UniqueConstraint("item_id", "goal_id", name="uq_knowledge_goal_links_pair"),
        Index("ix_knowledge_goal_links_goal", "goal_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    item_id: Mapped[int] = mapped_column(
        ForeignKey("knowledge_items.id", ondelete="CASCADE"),
        nullable=False,
    )
    goal_id: Mapped[int] = mapped_column(
        ForeignKey("goals.id", ondelete="CASCADE"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )


class KnowledgeObservation(Base):
    """Observação curta registrada dentro de um conhecimento."""

    __tablename__ = "knowledge_observations"
    __table_args__ = (Index("ix_knowledge_observations_item", "item_id"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    item_id: Mapped[int] = mapped_column(
        ForeignKey("knowledge_items.id", ondelete="CASCADE"),
        nullable=False,
    )
    text: Mapped[str] = mapped_column(String(2000), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )


class KnowledgeAttachment(Base):
    """Arquivo anexado a um conhecimento, guardado no banco."""

    __tablename__ = "knowledge_attachments"
    __table_args__ = (
        Index("ix_knowledge_attachments_item", "item_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    item_id: Mapped[int] = mapped_column(
        ForeignKey("knowledge_items.id", ondelete="CASCADE"),
        nullable=False,
    )
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    content_type: Mapped[str] = mapped_column(String(120), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    content: Mapped[bytes] = mapped_column(
        LargeBinary().with_variant(LONGBLOB(), "mysql"),
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )
