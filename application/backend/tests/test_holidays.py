from collections.abc import Iterator
from datetime import date

import pytest
from fastapi.testclient import TestClient

from app.core.errors import AppError
from app.data import holidays as holiday_source
from app.data.holidays import fetch_public_holidays
from app.services import holiday_service
from tests.conftest import auth_headers

# Dois feriados globais por ano e um regional, que não deve entrar.
BASE_HOLIDAYS = [
    {"month_day": "01-01", "localName": "Confraternização Universal", "name": "New Year's Day"},
    {"month_day": "04-03", "localName": "Sexta-feira Santa", "name": "Good Friday"},
    {"month_day": "08-09", "localName": "Feriado regional", "name": "Regional Day", "global": False},
]
SWEDEN_BASE_HOLIDAYS = [
    {"month_day": "01-06", "localName": "Trettondedag jul", "name": "Epiphany"},
    {"month_day": "06-19", "localName": "Midsommarafton", "name": "Midsummer Eve"},
]

CURRENT_YEAR = date.today().year
YEARS = [CURRENT_YEAR, CURRENT_YEAR + 1]


def _holidays_for(year: int, items: list[dict]) -> list[dict]:
    return [
        {
            "date": f"{year}-{item['month_day']}",
            "localName": item["localName"],
            "name": item["name"],
            "countryCode": "BR",
            "global": item.get("global", True),
        }
        for item in items
    ]


def _expected_days(items: list[dict]) -> set[str]:
    return {
        f"{year}-{item['month_day']}"
        for year in YEARS
        for item in items
        if item.get("global", True)
    }


@pytest.fixture
def fake_source(monkeypatch: pytest.MonkeyPatch) -> dict[tuple[int, str], list[dict]]:
    calls: dict[tuple[int, str], list[dict]] = {}

    def fake_fetch(year: int, iso2: str) -> list[dict]:
        calls[(year, iso2)] = []
        if iso2 == "BR":
            return _holidays_for(year, BASE_HOLIDAYS)
        return _holidays_for(year, SWEDEN_BASE_HOLIDAYS)

    monkeypatch.setattr(holiday_service, "fetch_public_holidays", fake_fetch)
    return calls


@pytest.fixture
def headers(client: TestClient, admin_auth: dict) -> Iterator[dict[str, str]]:
    yield auth_headers(admin_auth)


def _sync(
    client: TestClient,
    headers: dict[str, str],
    iso2: str = "BR",
) -> dict:
    return client.post(
        "/api/v1/holidays/sync",
        json={"country_iso2": iso2},
        headers=headers,
    )


def test_requires_authentication(client: TestClient) -> None:
    response = client.post(
        "/api/v1/holidays/sync",
        json={"country_iso2": "BR"},
    )
    assert response.status_code == 401


def test_syncs_current_and_next_year_and_stores_them(
    client: TestClient,
    headers: dict[str, str],
    fake_source: dict,
) -> None:
    response = _sync(client, headers)

    assert response.status_code == 200
    body = response.json()
    assert body["code"] == "HOLIDAYS_SYNCED"
    assert body["meta"]["country_iso2"] == "BR"
    assert body["meta"]["years"] == YEARS
    # Cada ano devolve os dois feriados globais; o regional fica de fora.
    assert body["meta"]["total"] == 4
    assert {item["day"] for item in body["data"]} == _expected_days(BASE_HOLIDAYS)
    assert body["data"][0]["local_name"] == "Confraternização Universal"
    assert set(fake_source) == {(year, "BR") for year in YEARS}


def test_sync_replaces_previous_country(
    client: TestClient,
    headers: dict[str, str],
    fake_source: dict,
) -> None:
    _sync(client, headers, "BR")
    response = _sync(client, headers, "SE")

    assert response.status_code == 200
    days = {item["day"] for item in response.json()["data"]}
    assert days == _expected_days(SWEDEN_BASE_HOLIDAYS)


def test_rejects_country_without_holidays(
    client: TestClient,
    headers: dict[str, str],
    fake_source: dict,
) -> None:
    response = _sync(client, headers, "PT")

    assert response.status_code == 422
    body = response.json()
    assert body["code"] == "HOLIDAY_COUNTRY_NOT_ENABLED"
    assert "Brasil" in body["message"]
    assert "Suécia" in body["message"]
    assert fake_source == {}


def test_source_failure_keeps_the_calendar_as_it_was(
    client: TestClient,
    headers: dict[str, str],
    fake_source: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _sync(client, headers, "BR")

    def broken(year: int, iso2: str) -> list[dict]:
        raise AppError(
            code="HOLIDAY_SOURCE_UNAVAILABLE",
            message="Não foi possível consultar os feriados agora.",
            status_code=502,
        )

    monkeypatch.setattr(holiday_service, "fetch_public_holidays", broken)
    response = _sync(client, headers, "SE")

    assert response.status_code == 502
    assert response.json()["code"] == "HOLIDAY_SOURCE_UNAVAILABLE"

    summary = client.get(
        "/api/v1/agenda/summary",
        params={
            "from": f"{CURRENT_YEAR}-01-01",
            "to": f"{CURRENT_YEAR}-12-31",
        },
        headers=headers,
    ).json()
    assert summary["data"][0]["holiday"] == "Confraternização Universal"


def test_holiday_appears_in_the_calendar_without_note_or_activity(
    client: TestClient,
    headers: dict[str, str],
    fake_source: dict,
) -> None:
    _sync(client, headers)
    first_holiday = f"{CURRENT_YEAR}-01-01"

    summary = client.get(
        "/api/v1/agenda/summary",
        params={"from": f"{CURRENT_YEAR}-01-01", "to": f"{CURRENT_YEAR}-12-31"},
        headers=headers,
    ).json()
    january = [day for day in summary["data"] if day["day"] == first_holiday][0]
    assert january == {
        "day": first_holiday,
        "has_note": False,
        "activities_total": 0,
        "activities_done": 0,
        "highest_priority": None,
        "tags": [],
        "holiday": "Confraternização Universal",
    }

    day = client.get(
        f"/api/v1/agenda/days/{first_holiday}",
        headers=headers,
    ).json()["data"]
    assert day["holiday"] == "Confraternização Universal"
    assert day["notes"] == []
    assert day["activities"] == []


def test_holidays_belong_to_the_user(
    client: TestClient,
    headers: dict[str, str],
    user_auth: dict,
    fake_source: dict,
) -> None:
    _sync(client, headers)

    other_headers = auth_headers(user_auth)
    summary = client.get(
        "/api/v1/agenda/summary",
        params={"from": f"{CURRENT_YEAR}-01-01", "to": f"{CURRENT_YEAR}-12-31"},
        headers=other_headers,
    ).json()
    assert summary["data"] == []

    day = client.get(
        f"/api/v1/agenda/days/{CURRENT_YEAR}-01-01",
        headers=other_headers,
    ).json()["data"]
    assert day["holiday"] is None


def test_source_failure_is_reported(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def broken(request: object, timeout: int) -> None:
        raise holiday_source.urllib.error.URLError("sem rede")

    monkeypatch.setattr(holiday_source.urllib.request, "urlopen", broken)

    with pytest.raises(AppError) as error:
        fetch_public_holidays(CURRENT_YEAR, "BR")

    assert error.value.code == "HOLIDAY_SOURCE_UNAVAILABLE"
    assert error.value.status_code == 502


def test_next_sync_is_idempotent(
    client: TestClient,
    headers: dict[str, str],
    fake_source: dict,
) -> None:
    first = _sync(client, headers).json()
    second = _sync(client, headers).json()

    assert second["meta"]["total"] == first["meta"]["total"]
    assert [item["day"] for item in second["data"]] == [
        item["day"] for item in first["data"]
    ]
