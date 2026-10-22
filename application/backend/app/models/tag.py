from datetime import datetime
from enum import StrEnum

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from atena_pattern.core.database import Base
from atena_pattern.models.user import utc_now


class TagTarget(StrEnum):
    """O que pode receber uma tag.

    `AGENDA_DAY` guarda a data como ordinal (``date.toordinal()``), porque o
    dia não precisa de linha própria em `agenda_days` para ser marcado.
    """

    KNOWLEDGE = "KNOWLEDGE"
    GOAL = "GOAL"
    AGENDA_DAY = "AGENDA_DAY"


class Tag(Base):
    """Etiqueta do usuário, com cor e descrição, reutilizada entre registros."""

    __tablename__ = "tags"
    __table_args__ = (
        UniqueConstraint("user_id", "name", name="uq_tags_user_name"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    name: Mapped[str] = mapped_column(String(40), nullable=False)
    color: Mapped[str] = mapped_column(String(7), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
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


class TagLink(Base):
    """Ligação N:M entre uma tag e o registro marcado.

    O alvo é polimórfico (`target_type` + `target_id`), então a remoção do
    registro precisa limpar as ligações no serviço responsável.
    """

    __tablename__ = "tag_links"
    __table_args__ = (
        UniqueConstraint(
            "tag_id",
            "target_type",
            "target_id",
            name="uq_tag_links_target",
        ),
        Index("ix_tag_links_target", "target_type", "target_id"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    tag_id: Mapped[int] = mapped_column(
        ForeignKey("tags.id", ondelete="CASCADE"),
        nullable=False,
    )
    target_type: Mapped[TagTarget] = mapped_column(
        Enum(TagTarget, name="tag_target"),
        nullable=False,
    )
    target_id: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )
