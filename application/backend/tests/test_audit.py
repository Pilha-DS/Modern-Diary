from datetime import date, datetime, timedelta, timezone

from fastapi.testclient import TestClient

from app.core.request_context import (
    client_day,
    reset_client_offset_minutes,
    set_client_offset_minutes,
)
from tests.conftest import auth_headers

OFFSET_HEADER = {"X-Client-Offset-Minutes": "0"}


def _headers(auth: dict) -> dict[str, str]:
    return {**auth_headers(auth), **OFFSET_HEADER}


def _utc_today() -> date:
    return datetime.now(timezone.utc).date()


def _create_knowledge(client: TestClient, headers: dict, title: str) -> dict:
    response = client.post(
        "/api/v1/knowledge",
        json={"title": title, "content": f"Sobre {title}"},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _create_goal(client: TestClient, headers: dict, title: str) -> dict:
    response = client.post(
        "/api/v1/goals",
        json={"title": title},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def test_audit_requires_auth(client: TestClient) -> None:
    response = client.get(
        "/api/v1/audit/days", params={"from": "2026-10-01", "to": "2026-10-31"}
    )

    assert response.status_code == 401
    assert response.json()["code"] == "UNAUTHORIZED"


def test_secret_cannot_read_the_audit(client: TestClient, user_auth: dict) -> None:
    headers = _headers(user_auth)
    secret = client.post(
        "/api/v1/secrets",
        json={
            "name": "integracao",
            "permissions": {
                "conhecimentos": {"read": "all", "create": True, "write": True}
            },
        },
        headers=headers,
    ).json()["data"]

    response = client.get(
        "/api/v1/audit/days",
        params={"from": "2026-10-01", "to": "2026-10-31"},
        headers={"Authorization": f"Bearer {secret['token']}"},
    )

    assert response.status_code == 403
    assert response.json()["code"] == "SESSION_REQUIRED"


def test_records_actions_and_links_of_the_day(
    client: TestClient, user_auth: dict
) -> None:
    headers = _headers(user_auth)
    first = _create_knowledge(client, headers, "SQL")
    second = _create_knowledge(client, headers, "Índices")
    goal = _create_goal(client, headers, "Aprender banco de dados")

    relation = client.post(
        f"/api/v1/knowledge/{first['id']}/relations",
        json={"target_id": second["id"]},
        headers=headers,
    )
    assert relation.status_code == 201
    link = client.post(
        f"/api/v1/knowledge/{first['id']}/goals",
        json={"goal_id": goal["id"]},
        headers=headers,
    )
    assert link.status_code == 201

    day = _utc_today()
    listed = client.get(
        f"/api/v1/audit/days/{day.isoformat()}",
        params={"per_page": 100},
        headers=headers,
    ).json()

    assert listed["code"] == "AUDIT_LISTED"
    entries = listed["data"]
    assert listed["meta"]["total"] == len(entries)
    assert listed["meta"]["total"] >= 5

    kinds = {entry["kind"] for entry in entries}
    assert {"CREATE", "LINK"} <= kinds

    relation_entry = next(entry for entry in entries if entry["kind"] == "LINK")
    assert relation_entry["source"]["type"] == "knowledge"
    assert relation_entry["target"]["type"] in {"knowledge", "goal"}
    assert relation_entry["occurred_at"].endswith("Z")

    graph = client.get(
        f"/api/v1/audit/days/{day.isoformat()}/graph", headers=headers
    ).json()

    assert graph["code"] == "AUDIT_GRAPH"
    node_ids = {node["id"] for node in graph["data"]["nodes"]}
    assert f"day:{day.isoformat()}" in node_ids
    assert f"knowledge:{first['id']}" in node_ids
    assert f"knowledge:{second['id']}" in node_ids
    assert f"goal:{goal['id']}" in node_ids

    pairs = {
        frozenset((edge["source"], edge["target"]))
        for edge in graph["data"]["edges"]
    }
    assert frozenset(
        (f"knowledge:{first['id']}", f"knowledge:{second['id']}")
    ) in pairs
    assert frozenset((f"knowledge:{first['id']}", f"goal:{goal['id']}")) in pairs


def test_day_counts_come_from_the_back(client: TestClient, user_auth: dict) -> None:
    headers = _headers(user_auth)
    _create_knowledge(client, headers, "Um")
    _create_knowledge(client, headers, "Dois")

    today = _utc_today()
    response = client.get(
        "/api/v1/audit/days",
        params={
            "from": (today - timedelta(days=1)).isoformat(),
            "to": (today + timedelta(days=1)).isoformat(),
        },
        headers=headers,
    ).json()

    assert response["code"] == "AUDIT_DAYS_LISTED"
    days = {entry["day"]: entry["total"] for entry in response["data"]}
    assert days[today.isoformat()] >= 2
    assert response["meta"]["total"] >= 2

    invalid = client.get(
        "/api/v1/audit/days",
        params={"from": "2026-10-31", "to": "2026-10-01"},
        headers=headers,
    )
    assert invalid.status_code == 422
    assert invalid.json()["code"] == "AUDIT_INVALID_RANGE"


def test_audit_is_isolated_per_user(
    client: TestClient, admin_auth: dict, user_auth: dict
) -> None:
    owner = _headers(admin_auth)
    other = _headers(user_auth)
    _create_knowledge(client, owner, "Privado do admin")

    today = _utc_today()
    response = client.get(
        f"/api/v1/audit/days/{today.isoformat()}", headers=other
    ).json()

    assert response["data"] == []
    assert response["meta"]["total"] == 0

    graph = client.get(
        f"/api/v1/audit/days/{today.isoformat()}/graph", headers=other
    ).json()
    assert graph["data"]["nodes"] == []
    assert graph["data"]["edges"] == []


def test_event_day_uses_the_client_offset() -> None:
    moment = datetime(2026, 10, 21, 2, 30)
    token = set_client_offset_minutes(-180)
    try:
        assert client_day(moment) == date(2026, 10, 20)
    finally:
        reset_client_offset_minutes(token)

    token = set_client_offset_minutes(840)
    try:
        assert client_day(moment) == date(2026, 10, 21)
    finally:
        reset_client_offset_minutes(token)


def test_pagination_keeps_the_total(client: TestClient, user_auth: dict) -> None:
    headers = _headers(user_auth)
    for title in ("Um", "Dois", "Três"):
        _create_knowledge(client, headers, title)

    today = _utc_today()
    response = client.get(
        f"/api/v1/audit/days/{today.isoformat()}",
        params={"page": 1, "per_page": 2},
        headers=headers,
    ).json()

    assert len(response["data"]) == 2
    assert response["meta"] == {
        "page": 1,
        "per_page": 2,
        "total": 3,
        "total_pages": 2,
    }
