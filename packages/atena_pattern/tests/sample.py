"""Modelo de domínio mínimo usado para exercitar o motor de permissões."""

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from atena_pattern.core.database import Base
from atena_pattern.models.sensitivity import Sensitivity, SensitivityType

AREA = "amostras"


class SampleRecord(Base):
    __tablename__ = "sample_records"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(80), nullable=False)
    sensitivity: Mapped[Sensitivity] = mapped_column(
        SensitivityType(),
        nullable=False,
        default=Sensitivity.PUBLIC,
    )
