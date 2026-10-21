from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.data.countries import count_countries, seed_countries
from tests.conftest import auth_headers


@pytest.fixture
def countries_headers(
    client: TestClient,
    session: Session,
    admin_auth: dict,
) -> Iterator[dict[str, str]]:
    seed_countries(session)
    yield auth_headers(admin_auth)


def test_countries_require_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/countries").status_code == 401


def test_seeds_the_full_iso_list(
    client: TestClient,
    session: Session,
    countries_headers: dict,
) -> None:
    assert count_countries(session) == 249

    response = client.get(
        "/api/v1/countries",
        params={"q": "BR"},
        headers=countries_headers,
    ).json()

    assert response["code"] == "COUNTRIES_LISTED"
    brazil = response["data"][0]
    assert brazil["iso2"] == "BR"
    assert brazil["iso3"] == "BRA"
    assert brazil["numeric_code"] == "076"
    assert brazil["name"] == "Brasil"
    assert brazil["long_name"] == "República Federativa do Brasil"
    assert brazil["phone_code"] == "+55"
    assert brazil["continent"] == "América do Sul"
    assert brazil["capital"] == "Brasília"
    assert brazil["currency_code"] == "BRL"
    assert brazil["currency_symbol"] == "R$"
    assert brazil["tld"] == ".br"
    assert brazil["flag_emoji"] == "🇧🇷"


def test_lists_alphabetically_with_pagination(
    client: TestClient,
    countries_headers: dict,
) -> None:
    first = client.get(
        "/api/v1/countries",
        params={"page": 1, "per_page": 5},
        headers=countries_headers,
    ).json()
    second = client.get(
        "/api/v1/countries",
        params={"page": 2, "per_page": 5},
        headers=countries_headers,
    ).json()

    assert first["meta"] == {
        "page": 1,
        "per_page": 5,
        "total": 249,
        "total_pages": 50,
    }
    names = [country["name"] for country in first["data"]]
    assert names == sorted(names)
    assert names[0] == "Afeganistão"
    assert first["data"][0]["iso2"] == "AF"
    # Páginas não repetem registro.
    assert not set(item["id"] for item in first["data"]) & set(
        item["id"] for item in second["data"]
    )


def test_searches_by_name_official_name_and_code(
    client: TestClient,
    countries_headers: dict,
) -> None:
    def listed(**params) -> list[str]:
        return [
            country["iso2"]
            for country in client.get(
                "/api/v1/countries",
                params=params,
                headers=countries_headers,
            ).json()["data"]
        ]

    assert "BR" in listed(q="brasil")
    assert "BR" in listed(q="federativa")
    # O código ISO entra na busca por igualdade; o texto continua valendo.
    assert "BR" in listed(q="BRA")
    assert "BR" in listed(q="br")
    assert "PT" in listed(q="portug")
    assert listed(q="xyz") == []


def test_filters_by_continent(
    client: TestClient,
    countries_headers: dict,
) -> None:
    response = client.get(
        "/api/v1/countries",
        params={"continent": "Europa", "per_page": 100},
        headers=countries_headers,
    ).json()

    continents = {country["continent"] for country in response["data"]}
    assert continents == {"Europa"}
    assert response["meta"]["total"] == len(response["data"])
    assert "PT" in [country["iso2"] for country in response["data"]]


def test_per_page_is_capped(
    client: TestClient,
    countries_headers: dict,
) -> None:
    response = client.get(
        "/api/v1/countries",
        params={"per_page": 500},
        headers=countries_headers,
    ).json()

    assert response["meta"]["per_page"] == 100
    assert len(response["data"]) == 100
