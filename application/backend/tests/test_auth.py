from fastapi.testclient import TestClient

from tests.conftest import auth_headers

ENVELOPE_KEYS = [
    "code",
    "success",
    "data",
    "message",
    "errors",
    "meta",
    "request_id",
    "timestamp",
]


def test_first_registration_creates_admin(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": "FirstUser", "password": "senha1234"},
    )

    body = response.json()
    assert response.status_code == 201
    assert list(body) == ENVELOPE_KEYS
    assert body["code"] == "USER_REGISTERED"
    assert body["success"] is True
    assert body["data"]["user"]["role"] == "ADMIN"
    assert body["data"]["user"]["username"] == "firstuser"
    assert body["data"]["token_type"] == "bearer"
    assert body["data"]["expires_in"] == 3600
    assert body["data"]["access_token"]
    assert body["meta"] == {}


def test_second_registration_creates_user(client: TestClient, admin_auth: dict) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": "second", "password": "senha1234"},
    )

    assert response.status_code == 201
    assert response.json()["data"]["user"]["role"] == "USER"


def test_admin_is_unique_even_after_many_registrations(
    client: TestClient, admin_auth: dict
) -> None:
    for index in range(3):
        client.post(
            "/api/v1/auth/register",
            json={"username": f"user{index}", "password": "senha1234"},
        )

    response = client.get("/api/v1/users", headers=auth_headers(admin_auth))
    roles = [user["role"] for user in response.json()["data"]]

    assert response.json()["meta"]["total"] == 4
    assert roles.count("ADMIN") == 1


def test_duplicate_username_returns_conflict(client: TestClient, admin_auth: dict) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": "ADMIN", "password": "senha1234"},
    )

    assert response.status_code == 409
    assert response.json()["code"] == "USERNAME_TAKEN"
    assert response.json()["success"] is False


def test_login_returns_token(client: TestClient, admin_auth: dict) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"username": "admin", "password": "admin1234"},
    )

    body = response.json()
    assert response.status_code == 200
    assert body["code"] == "AUTHENTICATED"
    assert body["data"]["user"]["role"] == "ADMIN"
    assert body["data"]["access_token"]


def test_login_with_wrong_password_fails(client: TestClient, admin_auth: dict) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"username": "admin", "password": "senhaerrada"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "INVALID_CREDENTIALS"


def test_login_with_unknown_username_fails(client: TestClient, admin_auth: dict) -> None:
    response = client.post(
        "/api/v1/auth/login",
        json={"username": "ninguem", "password": "senha1234"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "INVALID_CREDENTIALS"


def test_me_returns_authenticated_user(client: TestClient, admin_auth: dict) -> None:
    response = client.get("/api/v1/auth/me", headers=auth_headers(admin_auth))

    assert response.status_code == 200
    assert response.json()["code"] == "USER_PROFILE"
    assert response.json()["data"]["username"] == "admin"
    assert response.json()["data"]["created_at"].endswith("Z")


def test_me_without_token_is_unauthorized(client: TestClient) -> None:
    response = client.get("/api/v1/auth/me")

    assert response.status_code == 401
    assert response.json()["code"] == "UNAUTHORIZED"


def test_me_with_invalid_token_is_unauthorized(client: TestClient) -> None:
    response = client.get(
        "/api/v1/auth/me",
        headers={"Authorization": "Bearer token-invalido"},
    )

    assert response.status_code == 401
    assert response.json()["code"] == "INVALID_TOKEN"


def test_validation_error_uses_envelope(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": "ab", "password": "123"},
    )

    body = response.json()
    assert response.status_code == 422
    assert list(body) == ENVELOPE_KEYS
    assert body["code"] == "VALIDATION_ERROR"
    assert body["success"] is False
    assert body["data"] is None
    assert {error["field"] for error in body["errors"]} == {"username", "password"}


def test_request_id_is_echoed_when_valid(client: TestClient) -> None:
    response = client.get("/health", headers={"X-Request-ID": "req_test_1234"})

    assert response.headers["X-Request-ID"] == "req_test_1234"
    assert response.json()["request_id"] == "req_test_1234"


def test_health_uses_envelope(client: TestClient) -> None:
    response = client.get("/health")

    body = response.json()
    assert response.status_code == 200
    assert list(body) == ENVELOPE_KEYS
    assert body["code"] == "HEALTHY"
