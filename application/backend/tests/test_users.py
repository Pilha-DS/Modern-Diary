from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def test_user_has_any_permission_denied_on_admin_routes(
    client: TestClient, user_auth: dict
) -> None:
    response = client.get("/api/v1/users", headers=auth_headers(user_auth))

    assert response.status_code == 403
    assert response.json()["code"] == "FORBIDDEN"


def test_admin_lists_users_paginated(client: TestClient, admin_auth: dict, user_auth: dict) -> None:
    response = client.get(
        "/api/v1/users",
        params={"page": 1, "per_page": 1},
        headers=auth_headers(admin_auth),
    )

    body = response.json()
    assert response.status_code == 200
    assert body["code"] == "USERS_LISTED"
    assert len(body["data"]) == 1
    assert body["meta"] == {"page": 1, "per_page": 1, "total": 2, "total_pages": 2}


def test_per_page_above_ceiling_is_clamped(client: TestClient, admin_auth: dict) -> None:
    response = client.get(
        "/api/v1/users",
        params={"per_page": 5000},
        headers=auth_headers(admin_auth),
    )

    assert response.status_code == 200
    assert response.json()["meta"]["per_page"] == 100


def test_per_page_zero_is_rejected(client: TestClient, admin_auth: dict) -> None:
    response = client.get(
        "/api/v1/users",
        params={"per_page": 0},
        headers=auth_headers(admin_auth),
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_admin_promotes_user_to_moderator(
    client: TestClient, admin_auth: dict, user_auth: dict
) -> None:
    user_id = user_auth["user"]["id"]

    response = client.patch(
        f"/api/v1/users/{user_id}/role",
        json={"role": "MODERATOR"},
        headers=auth_headers(admin_auth),
    )

    assert response.status_code == 200
    assert response.json()["code"] == "USER_ROLE_UPDATED"
    assert response.json()["data"]["role"] == "MODERATOR"

    login = client.post(
        "/api/v1/auth/login",
        json={"username": "user", "password": "user1234"},
    )
    assert login.json()["data"]["user"]["role"] == "MODERATOR"


def test_admin_demotes_moderator_back_to_user(
    client: TestClient, admin_auth: dict, user_auth: dict
) -> None:
    user_id = user_auth["user"]["id"]
    headers = auth_headers(admin_auth)

    client.patch(f"/api/v1/users/{user_id}/role", json={"role": "MODERATOR"}, headers=headers)
    response = client.patch(
        f"/api/v1/users/{user_id}/role",
        json={"role": "USER"},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["data"]["role"] == "USER"


def test_admin_role_cannot_be_assigned(
    client: TestClient, admin_auth: dict, user_auth: dict
) -> None:
    response = client.patch(
        f"/api/v1/users/{user_auth['user']['id']}/role",
        json={"role": "ADMIN"},
        headers=auth_headers(admin_auth),
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_admin_role_cannot_be_changed(
    client: TestClient, admin_auth: dict
) -> None:
    response = client.patch(
        f"/api/v1/users/{admin_auth['user']['id']}/role",
        json={"role": "USER"},
        headers=auth_headers(admin_auth),
    )

    assert response.status_code == 409
    assert response.json()["code"] == "ADMIN_ROLE_FIXED"


def test_update_role_of_unknown_user_returns_not_found(
    client: TestClient, admin_auth: dict
) -> None:
    response = client.patch(
        "/api/v1/users/9999/role",
        json={"role": "MODERATOR"},
        headers=auth_headers(admin_auth),
    )

    assert response.status_code == 404
    assert response.json()["code"] == "USER_NOT_FOUND"


def test_moderator_cannot_manage_roles(
    client: TestClient, admin_auth: dict, user_auth: dict
) -> None:
    headers = auth_headers(admin_auth)
    user_id = user_auth["user"]["id"]

    client.patch(f"/api/v1/users/{user_id}/role", json={"role": "MODERATOR"}, headers=headers)
    login = client.post(
        "/api/v1/auth/login",
        json={"username": "user", "password": "user1234"},
    )
    moderator_headers = auth_headers(login.json()["data"])

    response = client.patch(
        f"/api/v1/users/{user_id}/role",
        json={"role": "USER"},
        headers=moderator_headers,
    )

    assert response.status_code == 403
    assert response.json()["code"] == "FORBIDDEN"


def test_unknown_route_uses_envelope(client: TestClient) -> None:
    response = client.get("/api/v1/nao-existe")

    assert response.status_code == 404
    assert response.json()["code"] == "NOT_FOUND"
    assert response.json()["data"] is None
