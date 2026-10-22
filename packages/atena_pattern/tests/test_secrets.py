from hashlib import sha256

from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from atena_pattern.models.api_secret import ApiSecret
from tests.conftest import auth_headers
from tests.sample import AREA


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
                AREA: {
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


def test_creates_secret_and_shows_token_only_once(
    client: TestClient, user_auth: dict, session: Session
) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(client, headers)

    assert secret["token"].startswith("mds_")
    assert secret["is_active"] is True
    assert secret["permissions"][AREA] == {
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


def test_rejects_unknown_area_and_level(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)

    bad_area = client.post(
        "/api/v1/secrets",
        json={
            "name": "invalida",
            "permissions": {"area-inexistente": {"read": "all"}},
        },
        headers=headers,
    )
    assert bad_area.status_code == 422
    assert bad_area.json()["code"] == "AREA_UNKNOWN"

    bad_level = client.post(
        "/api/v1/secrets",
        json={
            "name": "invalida",
            "permissions": {AREA: {"read": "ultra"}},
        },
        headers=headers,
    )
    assert bad_level.status_code == 422
    assert bad_level.json()["code"] == "VALIDATION_ERROR"


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

    assert client.get("/api/v1/auth/me", headers=secret_headers).status_code == 403

    revoked = client.delete(f"/api/v1/secrets/{secret['id']}", headers=headers)
    assert revoked.status_code == 200
    assert revoked.json()["code"] == "SECRET_REVOKED"
    assert revoked.json()["data"]["is_active"] is False

    blocked = client.get("/api/v1/auth/me", headers=secret_headers)
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

    stale = client.get("/api/v1/auth/me", headers=old_headers)
    assert stale.status_code == 401
    assert stale.json()["code"] == "INVALID_SECRET"

    fresh = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": f"Bearer {new_token}"},
    )
    assert fresh.status_code == 403
    assert fresh.json()["code"] == "SESSION_REQUIRED"


def test_secret_name_must_be_unique(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    _create_secret(client, headers, name="mesma")

    duplicated = client.post(
        "/api/v1/secrets",
        json={
            "name": "mesma",
            "permissions": {AREA: {"read": "all"}},
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
        permissions={AREA: {"read": "publico"}},
    )

    updated = client.patch(
        f"/api/v1/secrets/{secret['id']}",
        json={
            "name": "renomeada",
            "permissions": {
                AREA: {"read": "moderado", "create": True, "write": True}
            },
        },
        headers=headers,
    )
    assert updated.status_code == 200, updated.json()
    data = updated.json()["data"]
    assert data["name"] == "renomeada"
    assert data["permissions"] == {
        AREA: {"read": "moderado", "create": True, "write": True}
    }


def test_updates_permissions_of_the_same_area(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(
        client,
        headers,
        permissions={AREA: {"read": "publico"}},
    )

    updated = client.patch(
        f"/api/v1/secrets/{secret['id']}",
        json={
            "permissions": {
                AREA: {"read": "sigiloso", "create": True, "write": True}
            }
        },
        headers=headers,
    )
    assert updated.status_code == 200, updated.json()
    assert updated.json()["data"]["permissions"] == {
        AREA: {"read": "sigiloso", "create": True, "write": True}
    }

    detail = client.get(f"/api/v1/secrets/{secret['id']}", headers=headers).json()
    assert detail["data"]["permissions"][AREA]["read"] == "sigiloso"


def test_lists_secret_audit_paginated(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    secret = _create_secret(client, headers)

    audit = client.get(f"/api/v1/secrets/{secret['id']}/audit", headers=headers)
    assert audit.status_code == 200
    assert audit.json()["data"] == []
    assert audit.json()["meta"] == {
        "page": 1,
        "per_page": 20,
        "total": 0,
        "total_pages": 0,
    }
