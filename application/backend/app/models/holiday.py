from datetime import date, datetime

from sqlalchemy import CHAR, Date, DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from atena_pattern.core.database import Base
from atena_pattern.models.user import utc_now


class Holiday(Base):
    """Feriado guardado a partir da fonte externa, por usuário e país.

    Não é nota nem atividade: é um status do dia, exibido no calendário. A
    cópia no banco evita consultar a fonte a cada abertura da agenda.
    """

    __tablename__ = "holiday"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "country_iso2",
            "day",
            "name",
            name="uq_holiday_user_country_day_name",
        ),
        Index("ix_holiday_user_day", "user_id", "day"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    country_iso2: Mapped[str] = mapped_column(CHAR(2), nullable=False)
    day: Mapped[date] = mapped_column(Date, nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    local_name: Mapped[str | None] = mapped_column(String(160), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime,
        nullable=False,
        default=utc_now,
        server_default=func.current_timestamp(),
    )

    @property
    def display_name(self) -> str:
        return self.local_name or self.name
