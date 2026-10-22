from hashlib import sha256

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from atena_pattern.models.api_secret import ApiSecret
from tests.conftest import auth_headers


def _create_secret(
    client: TestClient,
    headers: dict,
    *,
    name: str = "integracao",
    permissions: dict | None = None,
) -> dict:
    response = client.post(
        "/api/v1/secrets",
        json={
            "name": name,
            "permissions": permissions
            or {
                "conhecimentos": {
                    "read": "all",
                    "create": True,
                    "write": True,
                }
            },
        },
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _token_headers(secret: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {secret['token']}"}


def _create_knowledge(
    client: TestClient,
    headers: dict,
    title: str,
    *,
    sensitivity: str = "publico",
) -> dict:
    response = client.post(
        "/api/v1/knowledge",
        json={"title": title, "sensitivity": sensitivity},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def test_creates_secret_and_shows_token_only_once(
    client: TestClient, user_auth: dict, session: Session
) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(client, headers)

    assert secret["token"].startswith("mds_")
    assert secret["is_active"] is True
    assert secret["permissions"]["conhecimentos"] == {
        "read": "all",
        "create": True,
        "write": True,
    }

    stored = session.scalar(select(ApiSecret).where(ApiSecret.name == "integracao"))
    assert stored is not None
    assert stored.token_hash == sha256(secret["token"].encode()).hexdigest()
    assert secret["token"] not in (stored.token_hash, stored.token_hint)

    listed = client.get("/api/v1/secrets", headers=headers).json()
    assert len(listed["data"]) == 1
    assert "token" not in listed["data"][0]

    detail = client.get(f"/api/v1/secrets/{secret['id']}", headers=headers).json()
    assert "token" not in detail["data"]


def test_read_is_limited_by_sensitivity(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    public_item = _create_knowledge(client, headers, "Público")
    secret_item = _create_knowledge(
        client, headers, "Sigiloso", sensitivity="sigiloso"
    )

    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "complexo", "create": False, "write": False}
        },
    )
    secret_headers = _token_headers(secret)

    listed = client.get("/api/v1/knowledge", headers=secret_headers).json()
    assert [item["id"] for item in listed["data"]] == [public_item["id"]]
    assert listed["meta"]["total"] == 1

    hidden = client.get(f"/api/v1/knowledge/{secret_item['id']}", headers=secret_headers)
    assert hidden.status_code == 404
    assert hidden.json()["code"] == "KNOWLEDGE_NOT_FOUND"

    everything = _create_secret(
        client,
        headers,
        name="completa",
        permissions={
            "conhecimentos": {"read": "all", "create": False, "write": False}
        },
    )
    all_items = client.get("/api/v1/knowledge", headers=_token_headers(everything))
    assert len(all_items.json()["data"]) == 2


def test_creation_above_read_level_does_not_grant_access(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "publico", "create": True, "write": True}
        },
    )
    secret_headers = _token_headers(secret)

    created = client.post(
        "/api/v1/knowledge",
        json={"title": "Criado pela integração", "sensitivity": "sigiloso"},
        headers=secret_headers,
    )
    assert created.status_code == 201
    item_id = created.json()["data"]["id"]

    assert (
        client.get(f"/api/v1/knowledge/{item_id}", headers=secret_headers).status_code
        == 404
    )
    assert (
        client.patch(
            f"/api/v1/knowledge/{item_id}",
            json={"title": "Outro nome"},
            headers=secret_headers,
        ).status_code
        == 404
    )

    owner_view = client.get(f"/api/v1/knowledge/{item_id}", headers=headers).json()
    assert owner_view["data"]["title"] == "Criado pela integração"
    assert owner_view["data"]["sensitivity"] == "sigiloso"


def test_write_and_create_need_their_own_flags(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create_knowledge(client, headers, "Original")

    reader = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "all", "create": False, "write": False}
        },
    )
    reader_headers = _token_headers(reader)

    assert (
        client.patch(
            f"/api/v1/knowledge/{item['id']}",
            json={"title": "Alterado"},
            headers=reader_headers,
        ).json()["code"]
        == "WRITE_NOT_PERMITTED"
    )
    assert (
        client.post(
            "/api/v1/knowledge",
            json={"title": "Novo"},
            headers=reader_headers,
        ).json()["code"]
        == "CREATE_NOT_PERMITTED"
    )

    writer = _create_secret(
        client,
        headers,
        name="escrita",
        permissions={
            "conhecimentos": {"read": "all", "create": False, "write": True}
        },
    )
    updated = client.patch(
        f"/api/v1/knowledge/{item['id']}",
        json={"title": "Alterado pela integração"},
        headers=_token_headers(writer),
    )
    assert updated.status_code == 200
    assert updated.json()["data"]["title"] == "Alterado pela integração"


def test_areas_are_independent(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "all", "create": False, "write": False}
        },
    )
    secret_headers = _token_headers(secret)

    knowledge = client.get("/api/v1/knowledge", headers=secret_headers)
    assert knowledge.status_code == 200

    goals = client.get("/api/v1/goals", headers=secret_headers)
    assert goals.status_code == 403
    assert goals.json()["code"] == "AREA_NOT_PERMITTED"

    day = client.get("/api/v1/agenda/days/2026-10-20", headers=secret_headers)
    assert day.status_code == 403
    assert day.json()["code"] == "AREA_NOT_PERMITTED"

    activities = client.post(
        "/api/v1/agenda/days/2026-10-20/activities",
        json={"title": "Estudar"},
        headers=secret_headers,
    )
    assert activities.status_code == 403


def test_secret_cannot_manage_secrets_or_users(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(client, headers)
    secret_headers = _token_headers(secret)

    listed = client.get("/api/v1/secrets", headers=secret_headers)
    assert listed.status_code == 403
    assert listed.json()["code"] == "SESSION_REQUIRED"

    users = client.get("/api/v1/users", headers=secret_headers)
    assert users.status_code == 403


def test_revoked_secret_is_rejected(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(client, headers)
    secret_headers = _token_headers(secret)

    assert client.get("/api/v1/knowledge", headers=secret_headers).status_code == 200

    revoked = client.delete(f"/api/v1/secrets/{secret['id']}", headers=headers)
    assert revoked.status_code == 200
    assert revoked.json()["code"] == "SECRET_REVOKED"
    assert revoked.json()["data"]["is_active"] is False

    blocked = client.get("/api/v1/knowledge", headers=secret_headers)
    assert blocked.status_code == 401
    assert blocked.json()["code"] == "SECRET_REVOKED"


def test_rotation_invalidates_previous_token(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(client, headers)
    old_headers = _token_headers(secret)

    rotated = client.post(
        f"/api/v1/secrets/{secret['id']}/rotate", headers=headers
    )
    assert rotated.status_code == 200
    new_token = rotated.json()["data"]["token"]
    assert new_token != secret["token"]

    stale = client.get("/api/v1/knowledge", headers=old_headers)
    assert stale.status_code == 401
    assert stale.json()["code"] == "INVALID_SECRET"

    fresh = client.get(
        "/api/v1/knowledge",
        headers={"Authorization": f"Bearer {new_token}"},
    )
    assert fresh.status_code == 200


def test_audit_records_allowed_and_denied(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create_knowledge(client, headers, "Base")

    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "all", "create": True, "write": False}
        },
    )
    secret_headers = _token_headers(secret)

    client.patch(
        f"/api/v1/knowledge/{item['id']}",
        json={"title": "Negado"},
        headers=secret_headers,
    )
    client.post(
        "/api/v1/knowledge",
        json={"title": "Permitido"},
        headers=secret_headers,
    )

    audit = client.get(
        f"/api/v1/secrets/{secret['id']}/audit", headers=headers
    ).json()
    entries = audit["data"]

    assert entries[0]["action"] == "CREATE"
    assert entries[0]["result"] == "ALLOWED"
    assert entries[0]["target_type"] == "knowledge"
    assert entries[0]["target_id"] is not None
    assert entries[0]["request_id"]

    denied = next(entry for entry in entries if entry["result"] == "DENIED")
    assert denied["action"] == "UPDATE"
    assert denied["area"] == "conhecimentos"
    assert denied["target_id"] == item["id"]


def test_secret_only_sees_its_owner_data(
    client: TestClient, user_auth: dict
) -> None:
    owner_headers = auth_headers(user_auth)
    secret = _create_secret(client, owner_headers)

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "outro", "password": "senha1234"},
    ).json()["data"]
    other_headers = auth_headers(other)
    _create_knowledge(client, other_headers, "Do outro")

    listed = client.get("/api/v1/knowledge", headers=_token_headers(secret)).json()
    assert listed["data"] == []
    assert listed["meta"]["total"] == 0


def test_related_hidden_knowledge_is_not_exposed(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    public_item = _create_knowledge(client, headers, "Público")
    hidden_item = _create_knowledge(client, headers, "Sigiloso", sensitivity="sigiloso")
    client.post(
        f"/api/v1/knowledge/{public_item['id']}/relations",
        json={"target_id": hidden_item["id"]},
        headers=headers,
    )

    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "publico", "create": False, "write": False}
        },
    )
    detail = client.get(
        f"/api/v1/knowledge/{public_item['id']}",
        headers=_token_headers(secret),
    ).json()

    assert detail["data"]["relations"] == []


def test_hidden_goal_title_is_not_exposed(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    goal = client.post(
        "/api/v1/goals",
        json={"title": "Meta sigilosa", "sensitivity": "sigiloso"},
        headers=headers,
    ).json()["data"]
    item = _create_knowledge(client, headers, "Conhecimento público")
    client.post(
        f"/api/v1/knowledge/{item['id']}/goals",
        json={"goal_id": goal["id"]},
        headers=headers,
    )

    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "publico", "create": False, "write": False},
            "metas": {"read": "publico", "create": False, "write": False},
        },
    )
    detail = client.get(
        f"/api/v1/knowledge/{item['id']}",
        headers=_token_headers(secret),
    ).json()

    assert detail["data"]["goals"] == []

    goals = client.get("/api/v1/goals", headers=_token_headers(secret)).json()
    assert goals["data"] == []
    assert goals["meta"]["total"] == 0


def test_cannot_raise_sensitivity_above_read_level(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create_knowledge(client, headers, "Público")

    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "publico", "create": True, "write": True}
        },
    )
    response = client.patch(
        f"/api/v1/knowledge/{item['id']}",
        json={"sensitivity": "sigiloso"},
        headers=_token_headers(secret),
    )

    assert response.status_code == 403
    assert response.json()["code"] == "SENSITIVITY_NOT_ALLOWED"

    owner_view = client.get(f"/api/v1/knowledge/{item['id']}", headers=headers).json()
    assert owner_view["data"]["sensitivity"] == "publico"


def test_agenda_separates_days_and_activities(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    client.post(
        "/api/v1/agenda/days/2026-10-20/notes",
        json={"content": "Nota do dia"},
        headers=headers,
    )
    client.post(
        "/api/v1/agenda/days/2026-10-20/activities",
        json={"title": "Atividade"},
        headers=headers,
    )

    days_only = _create_secret(
        client,
        headers,
        name="so_dias",
        permissions={
            "dias": {"read": "all", "create": False, "write": False},
        },
    )
    day_view = client.get(
        "/api/v1/agenda/days/2026-10-20", headers=_token_headers(days_only)
    ).json()
    assert day_view["data"]["notes"][0]["content"] == "Nota do dia"
    assert day_view["data"]["activities"] == []

    activities_only = _create_secret(
        client,
        headers,
        name="so_atividades",
        permissions={
            "atividades": {"read": "all", "create": False, "write": False},
        },
    )
    activity_view = client.get(
        "/api/v1/agenda/days/2026-10-20", headers=_token_headers(activities_only)
    ).json()
    assert activity_view["data"]["notes"] == []
    assert len(activity_view["data"]["activities"]) == 1


def test_rejects_unknown_area_and_level(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)

    bad_area = client.post(
        "/api/v1/secrets",
        json={
            "name": "invalida",
            "permissions": {"tags": {"read": "all", "create": True, "write": True}},
        },
        headers=headers,
    )
    assert bad_area.status_code == 422

    bad_level = client.post(
        "/api/v1/secrets",
        json={
            "name": "invalida",
            "permissions": {
                "conhecimentos": {
                    "read": "ultra",
                    "create": True,
                    "write": True,
                }
            },
        },
        headers=headers,
    )
    assert bad_level.status_code == 422

    all_item = client.post(
        "/api/v1/knowledge",
        json={"title": "Inválido", "sensitivity": "all"},
        headers=headers,
    )
    assert all_item.status_code == 422


def test_secret_name_must_be_unique(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    _create_secret(client, headers, name="mesma")

    duplicated = client.post(
        "/api/v1/secrets",
        json={
            "name": "mesma",
            "permissions": {
                "conhecimentos": {"read": "all", "create": False, "write": False}
            },
        },
        headers=headers,
    )
    assert duplicated.status_code == 409
    assert duplicated.json()["code"] == "SECRET_NAME_EXISTS"


def test_updates_permissions_of_a_secret(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "publico", "create": False, "write": False}
        },
    )

    updated = client.patch(
        f"/api/v1/secrets/{secret['id']}",
        json={
            "name": "renomeada",
            "permissions": {
                "metas": {"read": "moderado", "create": True, "write": True}
            },
        },
        headers=headers,
    )
    assert updated.status_code == 200
    data = updated.json()["data"]
    assert data["name"] == "renomeada"
    assert data["permissions"] == {
        "metas": {"read": "moderado", "create": True, "write": True}
    }

    goals = client.get("/api/v1/goals", headers=_token_headers(secret))
    assert goals.status_code == 200
    assert (
        client.get("/api/v1/knowledge", headers=_token_headers(secret)).json()["code"]
        == "AREA_NOT_PERMITTED"
    )


def test_updates_permissions_of_the_same_area(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(
        client,
        headers,
        permissions={
            "conhecimentos": {"read": "publico", "create": False, "write": False}
        },
    )

    updated = client.patch(
        f"/api/v1/secrets/{secret['id']}",
        json={
            "permissions": {
                "conhecimentos": {"read": "sigiloso", "create": True, "write": True}
            }
        },
        headers=headers,
    )
    assert updated.status_code == 200, updated.json()
    assert updated.json()["data"]["permissions"] == {
        "conhecimentos": {"read": "sigiloso", "create": True, "write": True}
    }

    detail = client.get(f"/api/v1/secrets/{secret['id']}", headers=headers).json()
    assert detail["data"]["permissions"]["conhecimentos"]["read"] == "sigiloso"


def test_owner_session_keeps_full_access(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    _create_knowledge(client, headers, "Público")
    secret_item = _create_knowledge(client, headers, "Sigiloso", sensitivity="sigiloso")

    listed = client.get("/api/v1/knowledge", headers=headers).json()
    assert listed["meta"]["total"] == 2

    lowered = client.patch(
        f"/api/v1/knowledge/{secret_item['id']}",
        json={"sensitivity": "publico"},
        headers=headers,
    )
    assert lowered.status_code == 200
    assert lowered.json()["data"]["sensitivity"] == "publico"
