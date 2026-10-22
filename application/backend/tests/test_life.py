from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def _knowledge(client: TestClient, headers: dict, title: str) -> dict:
    response = client.post(
        "/api/v1/knowledge", json={"title": title}, headers=headers
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _goal(client: TestClient, headers: dict, title: str) -> dict:
    response = client.post("/api/v1/goals", json={"title": title}, headers=headers)
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _note(client: TestClient, headers: dict, title: str) -> dict:
    response = client.post(
        "/api/v1/notes",
        json={"title": title, "content": "conteúdo"},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _activity(client: TestClient, headers: dict, day: str, title: str) -> dict:
    response = client.post(
        f"/api/v1/agenda/days/{day}/activities",
        json={"title": title, "priority": "MEDIUM"},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _graph(client: TestClient, headers: dict, **params) -> dict:
    response = client.get("/api/v1/life/graph", params=params, headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()["data"]


def _node_ids(graph: dict) -> set[str]:
    return {node["id"] for node in graph["nodes"]}


def test_life_graph_requires_authentication(client: TestClient) -> None:
    response = client.get("/api/v1/life/graph")

    assert response.status_code == 401


def test_graph_shows_entities_and_relations(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    first = _knowledge(client, headers, "FastAPI")
    second = _knowledge(client, headers, "SQLAlchemy")
    goal = _goal(client, headers, "Aprender backend")
    client.post(
        f"/api/v1/knowledge/{first['id']}/relations",
        json={"target_id": second["id"]},
        headers=headers,
    )
    client.post(
        f"/api/v1/knowledge/{first['id']}/goals",
        json={"goal_id": goal["id"]},
        headers=headers,
    )

    graph = _graph(client, headers)

    ids = _node_ids(graph)
    assert f"knowledge:{first['id']}" in ids
    assert f"knowledge:{second['id']}" in ids
    assert f"goal:{goal['id']}" in ids
    edge_pairs = {(edge["source"], edge["target"]) for edge in graph["edges"]}
    assert _pair("knowledge", first["id"], "knowledge", second["id"]) in edge_pairs
    assert _pair("knowledge", first["id"], "goal", goal["id"]) in edge_pairs


def test_graph_connects_activity_to_its_day(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    activity = _activity(client, headers, "2026-10-21", "Estudar")

    graph = _graph(client, headers)

    assert "day:2026-10-21" in _node_ids(graph)
    edge_pairs = {(edge["source"], edge["target"]) for edge in graph["edges"]}
    assert (
        "activity:%d" % activity["id"],
        "day:2026-10-21",
    ) in edge_pairs


def test_links_two_different_entities_and_rejects_duplicates(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    note = _note(client, headers, "Ideia")
    goal = _goal(client, headers, "Lançar projeto")

    created = client.post(
        "/api/v1/life/links",
        json={
            "source_type": "note",
            "source_ref": str(note["id"]),
            "target_type": "goal",
            "target_ref": str(goal["id"]),
        },
        headers=headers,
    )
    assert created.status_code == 201, created.json()
    assert created.json()["code"] == "LIFE_LINK_CREATED"

    duplicate = client.post(
        "/api/v1/life/links",
        json={
            "source_type": "goal",
            "source_ref": str(goal["id"]),
            "target_type": "note",
            "target_ref": str(note["id"]),
        },
        headers=headers,
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "LIFE_LINK_EXISTS"

    graph = _graph(client, headers)
    custom = [
        edge for edge in graph["edges"] if edge["kind"] == "custom"
    ]
    assert len(custom) == 1
    assert custom[0]["link_id"] is not None
    assert {
        custom[0]["source"].split(":")[0],
        custom[0]["target"].split(":")[0],
    } == {"note", "goal"}


def test_unlinks_two_entities(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    first = _knowledge(client, headers, "Um")
    second = _knowledge(client, headers, "Dois")
    payload = {
        "source_type": "knowledge",
        "source_ref": str(first["id"]),
        "target_type": "knowledge",
        "target_ref": str(second["id"]),
    }
    client.post("/api/v1/life/links", json=payload, headers=headers)

    removed = client.request(
        "DELETE", "/api/v1/life/links", json=payload, headers=headers
    )

    assert removed.status_code == 200, removed.json()
    assert removed.json()["code"] == "LIFE_LINK_DELETED"
    assert [
        edge for edge in _graph(client, headers)["edges"]
        if edge["kind"] == "custom"
    ] == []

    again = client.request(
        "DELETE", "/api/v1/life/links", json=payload, headers=headers
    )
    assert again.status_code == 404
    assert again.json()["code"] == "LIFE_LINK_NOT_FOUND"


def test_links_a_day_and_activity(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    activity = _activity(client, headers, "2026-10-20", "Correr")

    created = client.post(
        "/api/v1/life/links",
        json={
            "source_type": "activity",
            "source_ref": str(activity["id"]),
            "target_type": "day",
            "target_ref": "2026-10-19",
        },
        headers=headers,
    )

    assert created.status_code == 201, created.json()
    graph = _graph(client, headers)
    assert "day:2026-10-19" in _node_ids(graph)


def test_rejects_self_link_and_unknown_entity(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _knowledge(client, headers, "Só um")

    self_link = client.post(
        "/api/v1/life/links",
        json={
            "source_type": "knowledge",
            "source_ref": str(item["id"]),
            "target_type": "knowledge",
            "target_ref": str(item["id"]),
        },
        headers=headers,
    )
    missing = client.post(
        "/api/v1/life/links",
        json={
            "source_type": "knowledge",
            "source_ref": "99999",
            "target_type": "goal",
            "target_ref": "99999",
        },
        headers=headers,
    )

    assert self_link.status_code == 422
    assert self_link.json()["code"] == "LIFE_LINK_SELF"
    assert missing.status_code == 404
    assert missing.json()["code"] == "LIFE_ENTITY_NOT_FOUND"


def test_other_user_entity_is_not_found(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _knowledge(client, headers, "Privado")

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "outro_life", "password": "senha1234"},
    ).json()["data"]
    other_headers = auth_headers(other)

    response = client.post(
        "/api/v1/life/links",
        json={
            "source_type": "knowledge",
            "source_ref": str(item["id"]),
            "target_type": "day",
            "target_ref": "2026-10-21",
        },
        headers=other_headers,
    )

    assert response.status_code == 404
    assert response.json()["code"] == "LIFE_ENTITY_NOT_FOUND"
    assert _node_ids(_graph(client, other_headers)) == set()


def test_filters_the_graph_by_type(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    _knowledge(client, headers, "FastAPI")
    _goal(client, headers, "Meta")

    graph = _graph(client, headers, types="goal")

    assert {node["type"] for node in graph["nodes"]} == {"goal"}

    invalid = client.get(
        "/api/v1/life/graph", params={"types": "planeta"}, headers=headers
    )
    assert invalid.status_code == 422
    assert invalid.json()["code"] == "LIFE_INVALID_TYPE"


def test_deleting_an_entity_removes_its_links(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    note = _note(client, headers, "Ideia")
    goal = _goal(client, headers, "Meta")
    client.post(
        "/api/v1/life/links",
        json={
            "source_type": "note",
            "source_ref": str(note["id"]),
            "target_type": "goal",
            "target_ref": str(goal["id"]),
        },
        headers=headers,
    )

    client.delete(f"/api/v1/notes/{note['id']}", headers=headers)

    graph = _graph(client, headers)
    assert f"note:{note['id']}" not in _node_ids(graph)
    assert [edge for edge in graph["edges"] if edge["kind"] == "custom"] == []


def _pair(
    first_type: str, first_id: int, second_type: str, second_id: int
) -> tuple[str, str]:
    return tuple(
        sorted((f"{first_type}:{first_id}", f"{second_type}:{second_id}"))
    )
