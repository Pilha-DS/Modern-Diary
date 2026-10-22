from sqlalchemy import CHAR, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from atena_pattern.core.database import Base


class Country(Base):
    """País de referência (ISO 3166-1), usado para a nacionalidade.

    Os dados são fixos, versionados junto da migration que cria a tabela: o
    cadastro do usuário e os ajustes escolhem um país daqui, sem digitar nome.
    """

    __tablename__ = "country"
    __table_args__ = (
        Index("ix_country_name", "name"),
        Index("ix_country_continent_name", "continent", "name"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    iso2: Mapped[str] = mapped_column(CHAR(2), unique=True, nullable=False)
    iso3: Mapped[str] = mapped_column(CHAR(3), unique=True, nullable=False)
    numeric_code: Mapped[str | None] = mapped_column(CHAR(3), nullable=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    long_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    native_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    phone_code: Mapped[str | None] = mapped_column(String(8), nullable=True)
    continent: Mapped[str] = mapped_column(String(24), nullable=False)
    capital: Mapped[str | None] = mapped_column(String(120), nullable=True)
    currency_code: Mapped[str | None] = mapped_column(CHAR(3), nullable=True)
    currency_symbol: Mapped[str | None] = mapped_column(String(8), nullable=True)
    tld: Mapped[str | None] = mapped_column(String(12), nullable=True)
    flag_emoji: Mapped[str] = mapped_column(String(8), nullable=False)
