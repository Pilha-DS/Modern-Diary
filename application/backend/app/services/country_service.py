from sqlalchemy.orm import Session

from app.models.country import Country
from app.repositories.country_repository import CountryRepository


class CountryService:
    """Países são dados de referência: só leitura, sem dono."""

    def __init__(self, session: Session) -> None:
        self.countries = CountryRepository(session)

    def list_countries(
        self,
        *,
        offset: int,
        limit: int,
        query: str | None = None,
        continent: str | None = None,
    ) -> tuple[list[Country], int]:
        return self.countries.list_page(
            offset,
            limit,
            query=query,
            continent=continent,
        )
