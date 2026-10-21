from datetime import date

from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def _create_tag(
    client: TestClient,
    headers: dict,
    *,
    name: str = "estudo",
    color: str = "#2e7d5b",
    description: str | None = "Conteúdo de estudo",
) -> dict:
    response = client.post(
        "/api/v1/tags",
        json={"name": name, "color": color, "description": description},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _create_knowledge(
    client: TestClient,
    headers: dict,
    *,
    title: str = "Um conhecimento",
    tag_ids: list[int] | None = None,
) -> dict:
    response = client.post(
        "/api/v1/knowledge",
        json={"title": title, "tag_ids": tag_ids or []},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _create_goal(
    client: TestClient,
    headers: dict,
    *,
    title: str = "Uma meta",
    tag_ids: list[int] | None = None,
) -> dict:
    response = client.post(
        "/api/v1/goals",
        json={"title": title, "tag_ids": tag_ids or []},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def test_tags_require_authentication(client: TestClient) -> None:
    response = client.get("/api/v1/tags")

    assert response.status_code == 401
    assert response.json()["code"] == "UNAUTHORIZED"


def test_creates_lists_updates_and_deletes_tag(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    tag = _create_tag(client, headers)

    assert tag["name"] == "estudo"
    assert tag["color"] == "#2E7D5B"
    assert tag["description"] == "Conteúdo de estudo"
    assert tag["usage_count"] == 0

    duplicate = client.post(
        "/api/v1/tags",
        json={"name": "ESTUDO", "color": "#4A7BA7"},
        headers=headers,
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "TAG_EXISTS"

    listed = client.get("/api/v1/tags", headers=headers).json()

    assert listed["code"] == "TAGS_LISTED"
    assert listed["meta"] == {
        "page": 1,
        "per_page": 20,
        "total": 1,
        "total_pages": 1,
    }
    assert listed["data"][0]["id"] == tag["id"]

    updated = client.patch(
        f"/api/v1/tags/{tag['id']}",
        json={"name": " leitura ", "color": "#94670f", "description": None},
        headers=headers,
    ).json()["data"]

    assert updated["name"] == "leitura"
    assert updated["color"] == "#94670F"
    assert updated["description"] is None

    deleted = client.delete(f"/api/v1/tags/{tag['id']}", headers=headers)

    assert deleted.status_code == 200
    assert deleted.json()["code"] == "TAG_DELETED"
    assert client.get("/api/v1/tags", headers=headers).json()["data"] == []


def test_validates_tag_fields(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)

    blank = client.post("/api/v1/tags", json={"name": "   "}, headers=headers)
    bad_color = client.post(
        "/api/v1/tags",
        json={"name": "estudo", "color": "verde"},
        headers=headers,
    )

    assert blank.status_code == 422
    assert blank.json()["code"] == "VALIDATION_ERROR"
    assert bad_color.status_code == 422
    assert bad_color.json()["code"] == "VALIDATION_ERROR"


def test_attaches_tags_to_knowledge(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    tag = _create_tag(client, headers)
    item = _create_knowledge(client, headers, tag_ids=[tag["id"]])

    assert item["tags"] == [
        {
            "id": tag["id"],
            "name": tag["name"],
            "color": tag["color"],
            "description": tag["description"],
        }
    ]

    cleared = client.patch(
        f"/api/v1/knowledge/{item['id']}",
        json={"tag_ids": []},
        headers=headers,
    ).json()["data"]
    assert cleared["tags"] == []

    updated = client.patch(
        f"/api/v1/knowledge/{item['id']}",
        json={"tag_ids": [tag["id"]]},
        headers=headers,
    ).json()["data"]
    assert [tag["id"]] == [entry["id"] for entry in updated["tags"]]

    listed = client.get("/api/v1/knowledge", headers=headers).json()["data"]
    assert [entry["id"] for entry in listed[0]["tags"]] == [tag["id"]]


def test_attaches_tags_to_goal(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    tag = _create_tag(client, headers, name="saúde")
    goal = _create_goal(client, headers, tag_ids=[tag["id"]])

    assert [entry["id"] for entry in goal["tags"]] == [tag["id"]]

    listed = client.get("/api/v1/goals", headers=headers).json()["data"]

    assert [entry["id"] for entry in listed[0]["tags"]] == [tag["id"]]

    changed = client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"tag_ids": []},
        headers=headers,
    ).json()["data"]
    assert changed["tags"] == []


def test_filters_knowledge_and_goals_by_tag(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    study = _create_tag(client, headers, name="estudo")
    health = _create_tag(client, headers, name="saúde")

    first = _create_knowledge(
        client, headers, title="Com tag", tag_ids=[study["id"]]
    )
    second = _create_knowledge(client, headers, title="Sem tag")
    _create_goal(client, headers, title="Meta com tag", tag_ids=[study["id"]])
    _create_goal(client, headers, title="Meta com outra tag", tag_ids=[health["id"]])

    filtered = client.get(
        "/api/v1/knowledge",
        params={"tag_id": study["id"]},
        headers=headers,
    ).json()
    assert [entry["id"] for entry in filtered["data"]] == [first["id"]]
    assert filtered["meta"]["total"] == 1
    assert second["id"] not in [entry["id"] for entry in filtered["data"]]

    goals = client.get(
        "/api/v1/goals",
        params={"tag_id": study["id"]},
        headers=headers,
    ).json()
    assert [entry["title"] for entry in goals["data"]] == ["Meta com tag"]
    assert goals["meta"]["total"] == 1
    assert goals["meta"]["counts"]["ACTIVE"] == 1


def test_filters_knowledge_graph_by_tag(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    study = _create_tag(client, headers, name="estudo")

    first = _create_knowledge(
        client, headers, title="Com tag", tag_ids=[study["id"]]
    )
    second = _create_knowledge(client, headers, title="Sem tag")
    client.post(
        f"/api/v1/knowledge/{first['id']}/relations",
        json={"target_id": second["id"]},
        headers=headers,
    )

    graph = client.get(
        "/api/v1/knowledge/graph",
        params={"tag_id": study["id"]},
        headers=headers,
    ).json()

    assert graph["code"] == "KNOWLEDGE_GRAPH"
    assert graph["meta"]["total"] == 1
    node = graph["data"]["nodes"][0]
    assert node["id"] == first["id"]
    assert node["sensitivity"] == "publico"
    assert [tag["name"] for tag in node["tags"]] == ["estudo"]
    # O outro conhecimento fica fora do grafo, então a conexão não aparece.
    assert graph["data"]["edges"] == []


def test_attaches_tags_to_a_day(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    tag = _create_tag(client, headers, name="feriado")

    saved = client.put(
        "/api/v1/agenda/days/2026-10-20/tags",
        json={"tag_ids": [tag["id"]]},
        headers=headers,
    )

    assert saved.status_code == 200
    assert saved.json()["code"] == "AGENDA_DAY_TAGS_SAVED"
    assert [entry["id"] for entry in saved.json()["data"]["tags"]] == [tag["id"]]

    day = client.get("/api/v1/agenda/days/2026-10-20", headers=headers).json()["data"]
    assert [entry["name"] for entry in day["tags"]] == ["feriado"]

    summary = client.get(
        "/api/v1/agenda/summary",
        params={"from": "2026-10-01", "to": "2026-10-31"},
        headers=headers,
    ).json()["data"]

    assert summary == [
        {
            "day": "2026-10-20",
            "has_note": False,
            "activities_total": 0,
            "activities_done": 0,
            "highest_priority": None,
            "tags": [
                {
                    "id": tag["id"],
                    "name": "feriado",
                    "color": tag["color"],
                    "description": tag["description"],
                }
            ],
        }
    ]


def test_lists_usages_across_targets(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    tag = _create_tag(client, headers)
    item = _create_knowledge(client, headers, title="Criptografia", tag_ids=[tag["id"]])
    goal = _create_goal(client, headers, title="Aprender RSA", tag_ids=[tag["id"]])
    client.put(
        "/api/v1/agenda/days/2026-10-20/tags",
        json={"tag_ids": [tag["id"]]},
        headers=headers,
    )

    response = client.get(
        f"/api/v1/tags/{tag['id']}/usages",
        params={"per_page": 10},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["code"] == "TAG_USAGES_LISTED"
    assert response.json()["meta"]["total"] == 3

    usages = response.json()["data"]
    by_type = {usage["target_type"]: usage for usage in usages}

    assert by_type["KNOWLEDGE"]["title"] == "Criptografia"
    assert by_type["KNOWLEDGE"]["day"] is None
    assert by_type["GOAL"]["title"] == "Aprender RSA"
    assert by_type["AGENDA_DAY"]["day"] == "2026-10-20"
    assert by_type["AGENDA_DAY"]["target_id"] == date(2026, 10, 20).toordinal()

    listed = client.get("/api/v1/tags", headers=headers).json()["data"]
    assert listed[0]["usage_count"] == 3

    # Excluir o conhecimento tira a ligação dele da lista de usos.
    client.delete(f"/api/v1/knowledge/{item['id']}", headers=headers)
    remaining = client.get(
        f"/api/v1/tags/{tag['id']}/usages",
        headers=headers,
    ).json()

    assert remaining["meta"]["total"] == 2
    assert "KNOWLEDGE" not in {usage["target_type"] for usage in remaining["data"]}

    # Excluir a meta também.
    client.delete(f"/api/v1/goals/{goal['id']}", headers=headers)
    assert client.get(
        f"/api/v1/tags/{tag['id']}/usages", headers=headers
    ).json()["meta"]["total"] == 1


def test_deleting_tag_removes_its_links(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    tag = _create_tag(client, headers)
    item = _create_knowledge(client, headers, tag_ids=[tag["id"]])

    client.delete(f"/api/v1/tags/{tag['id']}", headers=headers)

    detail = client.get(f"/api/v1/knowledge/{item['id']}", headers=headers).json()
    assert detail["data"]["tags"] == []


def test_tag_is_scoped_to_the_owner(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    tag = _create_tag(client, headers)

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "outro", "password": "senha1234"},
    ).json()["data"]
    other_headers = auth_headers(other)

    stolen = client.post(
        "/api/v1/knowledge",
        json={"title": "Tentativa", "tag_ids": [tag["id"]]},
        headers=other_headers,
    )
    listed = client.get("/api/v1/tags", headers=other_headers)
    update = client.patch(
        f"/api/v1/tags/{tag['id']}",
        json={"name": "invadida"},
        headers=other_headers,
    )

    assert stolen.status_code == 404
    assert stolen.json()["code"] == "TAG_NOT_FOUND"
    assert listed.json()["data"] == []
    assert update.status_code == 404


def test_links_goal_to_knowledge(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    item = _create_knowledge(client, headers)
    goal = _create_goal(client, headers, title="Aprender RSA")

    linked = client.post(
        f"/api/v1/knowledge/{item['id']}/goals",
        json={"goal_id": goal["id"]},
        headers=headers,
    )

    assert linked.status_code == 201
    assert linked.json()["code"] == "KNOWLEDGE_GOAL_LINKED"

    detail = client.get(f"/api/v1/knowledge/{item['id']}", headers=headers).json()
    assert detail["data"]["goals"] == [{"id": goal["id"], "title": "Aprender RSA"}]

    duplicate = client.post(
        f"/api/v1/knowledge/{item['id']}/goals",
        json={"goal_id": goal["id"]},
        headers=headers,
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "KNOWLEDGE_GOAL_EXISTS"

    removed = client.delete(
        f"/api/v1/knowledge/{item['id']}/goals/{goal['id']}",
        headers=headers,
    )
    assert removed.status_code == 200
    assert removed.json()["code"] == "KNOWLEDGE_GOAL_UNLINKED"
    assert (
        client.get(f"/api/v1/knowledge/{item['id']}", headers=headers).json()["data"][
            "goals"
        ]
        == []
    )

    client.post(
        f"/api/v1/knowledge/{item['id']}/goals",
        json={"goal_id": goal["id"]},
        headers=headers,
    )
    client.delete(f"/api/v1/goals/{goal['id']}", headers=headers)

    assert (
        client.get(f"/api/v1/knowledge/{item['id']}", headers=headers).json()["data"][
            "goals"
        ]
        == []
    )


def test_cannot_link_goal_from_another_user(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create_knowledge(client, headers)

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "outro", "password": "senha1234"},
    ).json()["data"]
    other_headers = auth_headers(other)
    other_goal = _create_goal(client, other_headers)

    response = client.post(
        f"/api/v1/knowledge/{item['id']}/goals",
        json={"goal_id": other_goal["id"]},
        headers=headers,
    )

    assert response.status_code == 404
    assert response.json()["code"] == "GOAL_NOT_FOUND"
