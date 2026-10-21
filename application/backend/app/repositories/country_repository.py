from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session

from app.models.country import Country


class CountryRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_page(
        self,
        offset: int,
        limit: int,
        *,
        query: str | None = None,
        continent: str | None = None,
    ) -> tuple[list[Country], int]:
        filters = [*(self._search(query)), *(self._continent(continent))]
        total = self.session.scalar(
            select(func.count(Country.id)).where(*filters)
        ) or 0
        countries = self.session.scalars(
            select(Country)
            .where(*filters)
            # Ordem estável: nome e, no empate, a chave primária.
            .order_by(Country.name.asc(), Country.id.asc())
            .offset(offset)
            .limit(limit)
        ).all()
        return list(countries), total

    @staticmethod
    def _continent(continent: str | None) -> list:
        if not continent:
            return []
        return [Country.continent == continent]

    @staticmethod
    def _search(query: str | None) -> list:
        term = " ".join((query or "").split())
        if not term:
            return []
        # Tabela de referência (249 linhas): a busca pode olhar o texto todo.
        pattern = f"%{term}%"
        code = term.upper()
        return [
            or_(
                Country.name.ilike(pattern),
                Country.long_name.ilike(pattern),
                Country.native_name.ilike(pattern),
                Country.iso2 == code,
                Country.iso3 == code,
            )
        ]
