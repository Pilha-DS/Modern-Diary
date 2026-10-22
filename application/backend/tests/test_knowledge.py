from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def _create(
    client: TestClient,
    headers: dict,
    *,
    title: str = "FastAPI",
    content: str | None = "Framework para APIs",
    links: list[dict] | None = None,
) -> dict:
    response = client.post(
        "/api/v1/knowledge",
        json={"title": title, "content": content, "links": links or []},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def test_knowledge_requires_authentication(client: TestClient) -> None:
    response = client.get("/api/v1/knowledge")

    assert response.status_code == 401
    assert response.json()["code"] == "UNAUTHORIZED"


def test_creates_and_reads_knowledge_with_links(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    data = _create(
        client,
        headers,
        title="  FastAPI  ",
        content="Framework para APIs\n",
        links=[{"url": " https://fastapi.tiangolo.com ", "label": "Docs"}],
    )

    assert data["title"] == "FastAPI"
    assert data["content"] == "Framework para APIs"
    assert data["links"] == [
        {"url": "https://fastapi.tiangolo.com", "label": "Docs"}
    ]
    assert data["relations"] == []
    assert data["attachments"] == []

    detail = client.get(f"/api/v1/knowledge/{data['id']}", headers=headers)

    assert detail.status_code == 200
    assert detail.json()["code"] == "KNOWLEDGE_RETRIEVED"
    assert detail.json()["data"]["title"] == "FastAPI"


def test_updates_knowledge_and_clears_fields(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)

    updated = client.patch(
        f"/api/v1/knowledge/{item['id']}",
        json={"title": "FastAPI 2", "content": None, "links": []},
        headers=headers,
    ).json()["data"]

    assert updated["title"] == "FastAPI 2"
    assert updated["content"] is None
    assert updated["links"] == []


def test_deletes_knowledge(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)

    response = client.delete(f"/api/v1/knowledge/{item['id']}", headers=headers)

    assert response.status_code == 200
    assert response.json()["code"] == "KNOWLEDGE_DELETED"

    listed = client.get("/api/v1/knowledge", headers=headers).json()
    assert listed["data"] == []
    assert listed["meta"]["total"] == 0


def test_deleting_knowledge_removes_relations_and_attachments(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    first = _create(client, headers, title="Primeiro")
    second = _create(client, headers, title="Segundo")
    client.post(
        f"/api/v1/knowledge/{first['id']}/relations",
        json={"target_id": second["id"]},
        headers=headers,
    )
    attachment = client.post(
        f"/api/v1/knowledge/{first['id']}/attachments",
        files={"file": ("nota.txt", b"conteudo", "text/plain")},
        headers=headers,
    ).json()["data"]

    client.delete(f"/api/v1/knowledge/{first['id']}", headers=headers)

    remaining = client.get(
        f"/api/v1/knowledge/{second['id']}", headers=headers
    ).json()["data"]
    graph = client.get("/api/v1/knowledge/graph", headers=headers).json()["data"]
    download = client.get(attachment["download_url"])

    assert remaining["relations"] == []
    assert graph["edges"] == []
    assert download.status_code == 404


def test_lists_paginated_with_relations(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    for index in range(14):
        _create(client, headers, title=f"Conhecimento {index:02d}")

    first = client.get(
        "/api/v1/knowledge",
        params={"page": 1, "per_page": 12},
        headers=headers,
    ).json()
    second = client.get(
        "/api/v1/knowledge",
        params={"page": 2, "per_page": 12},
        headers=headers,
    ).json()

    assert len(first["data"]) == 12
    assert first["meta"] == {"page": 1, "per_page": 12, "total": 14, "total_pages": 2}
    assert len(second["data"]) == 2

    target = first["data"][0]
    other = first["data"][1]
    client.post(
        f"/api/v1/knowledge/{target['id']}/relations",
        json={"target_id": other["id"]},
        headers=headers,
    )

    listed = client.get(
        "/api/v1/knowledge", params={"per_page": 12}, headers=headers
    ).json()["data"]
    related = next(item for item in listed if item["id"] == target["id"])
    assert related["relations"] == [
        {"id": other["id"], "title": other["title"]}
    ]


def test_connects_and_disconnects_knowledge(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    first = _create(client, headers, title="Primeiro")
    second = _create(client, headers, title="Segundo")

    created = client.post(
        f"/api/v1/knowledge/{first['id']}/relations",
        json={"target_id": second["id"]},
        headers=headers,
    )

    assert created.status_code == 201
    assert created.json()["code"] == "KNOWLEDGE_RELATION_CREATED"

    duplicate = client.post(
        f"/api/v1/knowledge/{second['id']}/relations",
        json={"target_id": first["id"]},
        headers=headers,
    )
    assert duplicate.status_code == 409
    assert duplicate.json()["code"] == "KNOWLEDGE_RELATION_EXISTS"

    graph = client.get("/api/v1/knowledge/graph", headers=headers).json()

    assert graph["code"] == "KNOWLEDGE_GRAPH"
    assert graph["meta"]["total"] == 2
    nodes = {node["id"]: node for node in graph["data"]["nodes"]}
    assert nodes[first["id"]]["degree"] == 1
    assert nodes[second["id"]]["degree"] == 1
    assert graph["data"]["edges"] == [
        {"source": first["id"], "target": second["id"]}
    ]

    removed = client.delete(
        f"/api/v1/knowledge/{first['id']}/relations/{second['id']}",
        headers=headers,
    )
    assert removed.status_code == 200
    assert removed.json()["code"] == "KNOWLEDGE_RELATION_DELETED"

    graph = client.get("/api/v1/knowledge/graph", headers=headers).json()
    assert graph["data"]["edges"] == []


def test_rejects_self_relation(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)

    response = client.post(
        f"/api/v1/knowledge/{item['id']}/relations",
        json={"target_id": item["id"]},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["code"] == "KNOWLEDGE_SELF_LINK"


def test_manages_attachments(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)

    created = client.post(
        f"/api/v1/knowledge/{item['id']}/attachments",
        files={"file": ("resumo.txt", b"conteudo do anexo", "text/plain")},
        headers=headers,
    )

    assert created.status_code == 201
    attachment = created.json()["data"]
    assert attachment["filename"] == "resumo.txt"
    assert attachment["size_bytes"] == len(b"conteudo do anexo")

    downloaded = client.get(attachment["download_url"])

    assert downloaded.status_code == 200
    assert downloaded.content == b"conteudo do anexo"
    assert downloaded.headers["content-type"].startswith("text/plain")

    tampered = client.get(
        attachment["download_url"].split("?")[0] + "?token=invalido"
    )
    assert tampered.status_code == 401
    assert tampered.json()["code"] == "INVALID_TOKEN"

    listed = client.get(f"/api/v1/knowledge/{item['id']}", headers=headers).json()
    assert listed["data"]["attachments"][0]["id"] == attachment["id"]

    removed = client.delete(
        f"/api/v1/knowledge/{item['id']}/attachments/{attachment['id']}",
        headers=headers,
    )
    assert removed.status_code == 200
    assert removed.json()["code"] == "KNOWLEDGE_ATTACHMENT_DELETED"

    gone = client.get(attachment["download_url"])
    assert gone.status_code == 404
    assert gone.json()["code"] == "KNOWLEDGE_ATTACHMENT_NOT_FOUND"


def test_rejects_attachment_above_limit(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)

    response = client.post(
        f"/api/v1/knowledge/{item['id']}/attachments",
        files={"file": ("grande.bin", b"x" * (5 * 1024 * 1024 + 1), "application/octet-stream")},
        headers=headers,
    )

    assert response.status_code == 413
    assert response.json()["code"] == "KNOWLEDGE_ATTACHMENT_TOO_LARGE"


def test_other_user_cannot_access_knowledge(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "outro", "password": "senha1234"},
    ).json()["data"]
    other_headers = auth_headers(other)

    detail = client.get(f"/api/v1/knowledge/{item['id']}", headers=other_headers)
    update = client.patch(
        f"/api/v1/knowledge/{item['id']}",
        json={"title": "Invasão"},
        headers=other_headers,
    )
    relation = client.post(
        f"/api/v1/knowledge/{item['id']}/relations",
        json={"target_id": item["id"] + 1},
        headers=other_headers,
    )

    assert detail.status_code == 404
    assert update.status_code == 404
    assert relation.status_code == 404
    assert detail.json()["code"] == "KNOWLEDGE_NOT_FOUND"


def test_attachment_download_is_scoped_to_the_owner(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)
    created = client.post(
        f"/api/v1/knowledge/{item['id']}/attachments",
        files={"file": ("segredo.txt", b"privado", "text/plain")},
        headers=headers,
    ).json()["data"]

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "outro", "password": "senha1234"},
    ).json()["data"]
    other_headers = auth_headers(other)

    response = client.delete(
        f"/api/v1/knowledge/{item['id']}/attachments/{created['id']}",
        headers=other_headers,
    )

    assert response.status_code == 404
    assert response.json()["code"] == "KNOWLEDGE_ATTACHMENT_NOT_FOUND"


def test_validates_title_and_links(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)

    blank = client.post("/api/v1/knowledge", json={"title": "   "}, headers=headers)
    bad_link = client.post(
        "/api/v1/knowledge",
        json={"title": "Link", "links": [{"url": "ftp://arquivo"}]},
        headers=headers,
    )

    assert blank.status_code == 422
    assert blank.json()["code"] == "VALIDATION_ERROR"
    assert bad_link.status_code == 422
    assert bad_link.json()["code"] == "VALIDATION_ERROR"


def test_adds_and_removes_observations(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)

    first = client.post(
        f"/api/v1/knowledge/{item['id']}/observations",
        json={"text": "  Revisar decorators  "},
        headers=headers,
    )
    second = client.post(
        f"/api/v1/knowledge/{item['id']}/observations",
        json={"text": "Ler sobre Depends"},
        headers=headers,
    )

    assert first.status_code == 201
    assert first.json()["code"] == "KNOWLEDGE_OBSERVATION_CREATED"
    assert first.json()["data"]["text"] == "Revisar decorators"
    assert second.status_code == 201

    detail = client.get(f"/api/v1/knowledge/{item['id']}", headers=headers).json()
    texts = [row["text"] for row in detail["data"]["observations"]]
    assert texts == ["Revisar decorators", "Ler sobre Depends"]

    removed = client.delete(
        f"/api/v1/knowledge/{item['id']}/observations/"
        f"{first.json()['data']['id']}",
        headers=headers,
    )
    assert removed.status_code == 200
    assert removed.json()["code"] == "KNOWLEDGE_OBSERVATION_DELETED"

    detail = client.get(f"/api/v1/knowledge/{item['id']}", headers=headers).json()
    assert [row["text"] for row in detail["data"]["observations"]] == [
        "Ler sobre Depends"
    ]


def test_rejects_blank_observation(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)

    response = client.post(
        f"/api/v1/knowledge/{item['id']}/observations",
        json={"text": "   "},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_other_user_cannot_touch_observation(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    item = _create(client, headers)
    observation = client.post(
        f"/api/v1/knowledge/{item['id']}/observations",
        json={"text": "Privado"},
        headers=headers,
    ).json()["data"]

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "outro", "password": "senha1234"},
    ).json()["data"]
    other_headers = auth_headers(other)

    deleted = client.delete(
        f"/api/v1/knowledge/{item['id']}/observations/{observation['id']}",
        headers=other_headers,
    )

    assert deleted.status_code == 404
    assert deleted.json()["code"] == "KNOWLEDGE_NOT_FOUND"
