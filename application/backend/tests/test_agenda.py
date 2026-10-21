from datetime import date

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.agenda import AgendaActivity, Priority
from tests.conftest import auth_headers


def _register(client: TestClient, username: str) -> dict:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": username, "password": "senha1234"},
    )
    assert response.status_code == 201
    return response.json()["data"]


def test_agenda_requires_authentication(client: TestClient) -> None:
    response = client.get(
        "/api/v1/agenda/summary",
        params={"from": "2026-10-01", "to": "2026-10-31"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "UNAUTHORIZED"


def test_saves_note_and_reads_day(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    note = "# Terça\n\n- Estudar **FastAPI**"

    saved = client.put(
        "/api/v1/agenda/days/2026-10-20/note",
        json={"note": note},
        headers=headers,
    )

    assert saved.status_code == 200
    assert saved.json()["code"] == "AGENDA_NOTE_SAVED"
    assert saved.json()["data"]["note"] == note

    day = client.get("/api/v1/agenda/days/2026-10-20", headers=headers)

    assert day.status_code == 200
    assert day.json()["code"] == "AGENDA_DAY_RETRIEVED"
    assert day.json()["data"] == {
        "day": "2026-10-20",
        "note": note,
        "sensitivity": "publico",
        "activities": [],
        "tags": [],
    }


def test_blank_note_removes_day_from_summary(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    client.put(
        "/api/v1/agenda/days/2026-10-20/note",
        json={"note": "Alguma coisa"},
        headers=headers,
    )

    client.put(
        "/api/v1/agenda/days/2026-10-20/note",
        json={"note": "   "},
        headers=headers,
    )

    summary = client.get(
        "/api/v1/agenda/summary",
        params={"from": "2026-10-01", "to": "2026-10-31"},
        headers=headers,
    )

    assert summary.json()["data"] == []
    assert summary.json()["meta"]["total"] == 0


def test_creates_activity_with_time_and_priority(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)

    response = client.post(
        "/api/v1/agenda/days/2026-10-20/activities",
        json={"title": "  Reunião  ", "start_time": "09:30", "priority": "HIGH"},
        headers=headers,
    )

    body = response.json()
    assert response.status_code == 201
    assert body["code"] == "AGENDA_ACTIVITY_CREATED"
    assert body["data"]["title"] == "Reunião"
    assert body["data"]["start_time"] == "09:30"
    assert body["data"]["priority"] == "HIGH"
    assert body["data"]["is_done"] is False


def test_activities_are_sorted_by_time(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    for title, start_time in [("Sem hora", None), ("Tarde", "15:00"), ("Manhã", "08:00")]:
        client.post(
            "/api/v1/agenda/days/2026-10-20/activities",
            json={"title": title, "start_time": start_time},
            headers=headers,
        )

    day = client.get("/api/v1/agenda/days/2026-10-20", headers=headers).json()["data"]

    assert [activity["title"] for activity in day["activities"]] == [
        "Manhã",
        "Tarde",
        "Sem hora",
    ]


def test_updates_activity_and_clears_time(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    created = client.post(
        "/api/v1/agenda/days/2026-10-20/activities",
        json={"title": "Ler", "start_time": "20:00", "priority": "LOW"},
        headers=headers,
    ).json()["data"]

    updated = client.patch(
        f"/api/v1/agenda/activities/{created['id']}",
        json={"is_done": True, "start_time": None},
        headers=headers,
    )

    assert updated.status_code == 200
    assert updated.json()["code"] == "AGENDA_ACTIVITY_UPDATED"
    assert updated.json()["data"]["is_done"] is True
    assert updated.json()["data"]["start_time"] is None
    assert updated.json()["data"]["title"] == "Ler"


def test_deletes_activity(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    created = client.post(
        "/api/v1/agenda/days/2026-10-20/activities",
        json={"title": "Ler"},
        headers=headers,
    ).json()["data"]

    deleted = client.delete(f"/api/v1/agenda/activities/{created['id']}", headers=headers)

    assert deleted.status_code == 200
    assert deleted.json()["code"] == "AGENDA_ACTIVITY_DELETED"
    assert deleted.json()["data"] == {"id": created["id"]}

    day = client.get("/api/v1/agenda/days/2026-10-20", headers=headers).json()["data"]
    assert day["activities"] == []


def test_summary_aggregates_days_and_priorities(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    client.put(
        "/api/v1/agenda/days/2026-10-05/note",
        json={"note": "Nota do dia"},
        headers=headers,
    )
    client.post(
        "/api/v1/agenda/days/2026-10-05/activities",
        json={"title": "Alta", "priority": "HIGH"},
        headers=headers,
    )
    created = client.post(
        "/api/v1/agenda/days/2026-10-06/activities",
        json={"title": "Média", "priority": "MEDIUM"},
        headers=headers,
    ).json()["data"]
    client.patch(
        f"/api/v1/agenda/activities/{created['id']}",
        json={"is_done": True},
        headers=headers,
    )

    summary = client.get(
        "/api/v1/agenda/summary",
        params={"from": "2026-10-01", "to": "2026-10-31"},
        headers=headers,
    )

    body = summary.json()
    assert summary.status_code == 200
    assert body["code"] == "AGENDA_SUMMARY"
    assert body["meta"] == {"from": "2026-10-01", "to": "2026-10-31", "total": 2}
    assert body["data"] == [
        {
            "day": "2026-10-05",
            "has_note": True,
            "activities_total": 1,
            "activities_done": 0,
            "highest_priority": "HIGH",
            "tags": [],
        },
        {
            "day": "2026-10-06",
            "has_note": False,
            "activities_total": 1,
            "activities_done": 1,
            "highest_priority": "MEDIUM",
            "tags": [],
        },
    ]


def test_summary_rejects_range_above_one_year(client: TestClient, user_auth: dict) -> None:
    response = client.get(
        "/api/v1/agenda/summary",
        params={"from": "2026-01-01", "to": "2027-01-02"},
        headers=auth_headers(user_auth),
    )

    assert response.status_code == 422
    assert response.json()["code"] == "AGENDA_RANGE_TOO_LARGE"


def test_summary_rejects_inverted_range(client: TestClient, user_auth: dict) -> None:
    response = client.get(
        "/api/v1/agenda/summary",
        params={"from": "2026-10-31", "to": "2026-10-01"},
        headers=auth_headers(user_auth),
    )

    assert response.status_code == 422
    assert response.json()["code"] == "AGENDA_INVALID_RANGE"


def test_other_user_cannot_access_activity(client: TestClient, user_auth: dict) -> None:
    owner_headers = auth_headers(user_auth)
    created = client.post(
        "/api/v1/agenda/days/2026-10-20/activities",
        json={"title": "Privada"},
        headers=owner_headers,
    ).json()["data"]

    other_headers = auth_headers(_register(client, "outro"))

    update = client.patch(
        f"/api/v1/agenda/activities/{created['id']}",
        json={"is_done": True},
        headers=other_headers,
    )
    delete = client.delete(f"/api/v1/agenda/activities/{created['id']}", headers=other_headers)
    day = client.get("/api/v1/agenda/days/2026-10-20", headers=other_headers)

    assert update.status_code == 404
    assert update.json()["code"] == "AGENDA_ACTIVITY_NOT_FOUND"
    assert delete.status_code == 404
    assert day.json()["data"]["activities"] == []


def test_daily_activity_limit(client: TestClient, user_auth: dict, session: Session) -> None:
    for index in range(100):
        session.add(
            AgendaActivity(
                user_id=user_auth["user"]["id"],
                day=date(2026, 10, 20),
                title=f"Atividade {index}",
                priority=Priority.LOW,
            )
        )
    session.flush()

    response = client.post(
        "/api/v1/agenda/days/2026-10-20/activities",
        json={"title": "Excedente"},
        headers=auth_headers(user_auth),
    )

    assert response.status_code == 409
    assert response.json()["code"] == "AGENDA_ACTIVITY_LIMIT"


def test_invalid_time_is_validation_error(client: TestClient, user_auth: dict) -> None:
    response = client.post(
        "/api/v1/agenda/days/2026-10-20/activities",
        json={"title": "Inválida", "start_time": "25:00"},
        headers=auth_headers(user_auth),
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"
