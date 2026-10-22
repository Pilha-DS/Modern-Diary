from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.mysql import LONGTEXT
from sqlalchemy.orm import Mapped, mapped_column

from atena_pattern.core.database import Base
from atena_pattern.models.sensitivity import Sensitivity, SensitivityType
from atena_pattern.models.user import utc_now


class Note(Base):
    """Anotação livre do usuário, escrita em markdown.

    A nota tem título opcional (a lista mostra "Sem título" quando ele não
    existe) e guarda o conteúdo completo; a listagem devolve só uma prévia.
    """

    __tablename__ = "notes"
    __table_args__ = (
        Index("ix_notes_user_updated", "user_id", "updated_at"),
        Index("ix_notes_user_sensitivity", "user_id", "sensitivity"),
        Index("ix_notes_user_pinned_updated", "user_id", "is_pinned", "updated_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    title: Mapped[str | None] = mapped_column(String(160), nullable=True)
    content: Mapped[str] = mapped_column(
        Text().with_variant(LONGTEXT(), "mysql"),
        nullable=False,
    )
    is_pinned: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("0"),
    )
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
