from sqlalchemy import Boolean, text
from sqlalchemy.orm import Mapped, mapped_column

from atena_pattern.core.database import Base


class SystemState(Base):
    """Linha única que serializa o cadastro inicial e registra o primeiro admin."""

    __tablename__ = "system_state"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=False)
    admin_created: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        server_default=text("0"),
    )
