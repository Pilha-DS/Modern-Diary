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


def test_creates_notes_and_reads_day(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)

    first = client.post(
        "/api/v1/agenda/days/2026-10-20/notes",
        json={"content": "# Terça\n\n- Estudar **FastAPI**"},
        headers=headers,
    )
    second = client.post(
        "/api/v1/agenda/days/2026-10-20/notes",
        json={"content": "Segunda nota", "sensitivity": "sigiloso"},
        headers=headers,
    )

    assert first.status_code == 201
    assert first.json()["code"] == "AGENDA_NOTE_CREATED"
    assert second.status_code == 201

    day = client.get("/api/v1/agenda/days/2026-10-20", headers=headers)
    body = day.json()

    assert day.status_code == 200
    assert body["code"] == "AGENDA_DAY_RETRIEVED"
    assert body["data"]["day"] == "2026-10-20"
    assert body["data"]["sensitivity"] == "publico"
    assert body["data"]["activities"] == []
    assert body["data"]["tags"] == []
    assert body["data"]["holiday"] is None
    assert [note["content"] for note in body["data"]["notes"]] == [
        "# Terça\n\n- Estudar **FastAPI**",
        "Segunda nota",
    ]
    assert [note["sensitivity"] for note in body["data"]["notes"]] == [
        "publico",
        "sigiloso",
    ]


def test_updates_note_content_and_sensitivity(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    created = client.post(
        "/api/v1/agenda/days/2026-10-20/notes",
        json={"content": "Rascunho"},
        headers=headers,
    ).json()["data"]

    note_id = created["notes"][0]["id"]
    updated = client.patch(
        f"/api/v1/agenda/notes/{note_id}",
        json={"content": "Texto final", "sensitivity": "sigiloso"},
        headers=headers,
    )

    assert updated.status_code == 200
    assert updated.json()["code"] == "AGENDA_NOTE_UPDATED"
    assert updated.json()["data"]["content"] == "Texto final"
    assert updated.json()["data"]["sensitivity"] == "sigiloso"


def test_blank_note_is_validation_error(client: TestClient, user_auth: dict) -> None:
    response = client.post(
        "/api/v1/agenda/days/2026-10-20/notes",
        json={"content": "   "},
        headers=auth_headers(user_auth),
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_delete_last_note_removes_day_from_summary(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    created = client.post(
        "/api/v1/agenda/days/2026-10-20/notes",
        json={"content": "Alguma coisa"},
        headers=headers,
    ).json()["data"]
    note_id = created["notes"][0]["id"]

    deleted = client.delete(f"/api/v1/agenda/notes/{note_id}", headers=headers)

    assert deleted.status_code == 200
    assert deleted.json()["code"] == "AGENDA_NOTE_DELETED"
    assert deleted.json()["data"] == {"id": note_id}

    summary = client.get(
        "/api/v1/agenda/summary",
        params={"from": "2026-10-01", "to": "2026-10-31"},
        headers=headers,
    )

    assert summary.json()["data"] == []
    assert summary.json()["meta"]["total"] == 0


def test_sets_day_sensitivity(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)

    response = client.put(
        "/api/v1/agenda/days/2026-10-20/sensitivity",
        json={"sensitivity": "sigiloso"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["code"] == "AGENDA_DAY_SENSITIVITY_SAVED"
    assert response.json()["data"]["sensitivity"] == "sigiloso"
    assert response.json()["data"]["notes"] == []


def test_other_user_cannot_access_note(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    created = client.post(
        "/api/v1/agenda/days/2026-10-20/notes",
        json={"content": "Privada"},
        headers=headers,
    ).json()["data"]
    note_id = created["notes"][0]["id"]

    other_headers = auth_headers(_register(client, "outro_nota"))

    update = client.patch(
        f"/api/v1/agenda/notes/{note_id}",
        json={"content": "Invadida"},
        headers=other_headers,
    )
    delete = client.delete(f"/api/v1/agenda/notes/{note_id}", headers=other_headers)

    assert update.status_code == 404
    assert update.json()["code"] == "AGENDA_NOTE_NOT_FOUND"
    assert delete.status_code == 404


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
    client.post(
        "/api/v1/agenda/days/2026-10-05/notes",
        json={"content": "Nota do dia"},
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
            "holiday": None,
        },
        {
            "day": "2026-10-06",
            "has_note": False,
            "activities_total": 1,
            "activities_done": 1,
            "highest_priority": "MEDIUM",
            "tags": [],
            "holiday": None,
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
