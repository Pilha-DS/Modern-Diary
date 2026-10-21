import json
from functools import lru_cache
from pathlib import Path

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.country import Country

COUNTRIES_FILE = Path(__file__).with_name("countries.json")


@lru_cache(maxsize=1)
def load_country_rows() -> tuple[dict, ...]:
    """Linhas fixas de país, na ordem em que entram no banco.

    Fonte única: a migration 0008 e os testes usam este mesmo arquivo, então a
    lista de países nunca diverge entre ambientes.
    """
    with COUNTRIES_FILE.open(encoding="utf-8") as file:
        return tuple(json.load(file))


def seed_countries(session: Session) -> int:
    """Insere os países que ainda não existem. Devolve quantos entraram."""
    existing = set(session.scalars(select(Country.iso2)).all())
    rows = [row for row in load_country_rows() if row["iso2"] not in existing]
    if not rows:
        return 0
    session.add_all(Country(**row) for row in rows)
    session.commit()
    return len(rows)


def count_countries(session: Session) -> int:
    return session.scalar(select(func.count(Country.id))) or 0
