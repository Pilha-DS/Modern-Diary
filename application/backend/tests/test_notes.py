from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def _create(
    client: TestClient,
    headers: dict,
    *,
    title: str | None = "Ideias",
    content: str = "Primeira linha\n- [ ] estudar",
    sensitivity: str = "publico",
) -> dict:
    response = client.post(
        "/api/v1/notes",
        json={"title": title, "content": content, "sensitivity": sensitivity},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def test_notes_require_authentication(client: TestClient) -> None:
    assert client.get("/api/v1/notes").status_code == 401
    assert client.post("/api/v1/notes", json={"content": "x"}).status_code == 401


def test_creates_and_reads_note(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    data = _create(
        client,
        headers,
        title="  Ideias  ",
        content="# Projeto\n\nAnotar tudo.\n",
    )

    assert data["title"] == "Ideias"
    assert data["content"] == "# Projeto\n\nAnotar tudo."
    assert data["is_pinned"] is False
    assert data["sensitivity"] == "publico"

    detail = client.get(f"/api/v1/notes/{data['id']}", headers=headers)

    assert detail.status_code == 200
    assert detail.json()["code"] == "NOTE_RETRIEVED"
    assert detail.json()["data"]["content"] == "# Projeto\n\nAnotar tudo."


def test_title_is_optional(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    data = _create(client, headers, title="   ", content="Só o texto")

    assert data["title"] is None


def test_rejects_empty_content(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    response = client.post(
        "/api/v1/notes",
        json={"content": "   "},
        headers=headers,
    )

    assert response.status_code == 422
    assert response.json()["code"] == "VALIDATION_ERROR"


def test_updates_pins_and_clears_title(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    note = _create(client, headers)

    updated = client.patch(
        f"/api/v1/notes/{note['id']}",
        json={"content": "Novo texto", "is_pinned": True, "title": ""},
        headers=headers,
    ).json()

    assert updated["code"] == "NOTE_UPDATED"
    assert updated["data"]["content"] == "Novo texto"
    assert updated["data"]["title"] is None
    assert updated["data"]["is_pinned"] is True


def test_deletes_note(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    note = _create(client, headers)

    response = client.delete(f"/api/v1/notes/{note['id']}", headers=headers)

    assert response.status_code == 200
    assert response.json()["code"] == "NOTE_DELETED"

    listed = client.get("/api/v1/notes", headers=headers).json()
    assert listed["data"] == []
    assert listed["meta"]["total"] == 0


def test_lists_paginated_with_pinned_first(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    for index in range(14):
        _create(client, headers, title=f"Nota {index:02d}")
    pinned = _create(client, headers, title="Fixa")
    client.patch(
        f"/api/v1/notes/{pinned['id']}",
        json={"is_pinned": True},
        headers=headers,
    )

    first = client.get(
        "/api/v1/notes",
        params={"page": 1, "per_page": 12},
        headers=headers,
    ).json()
    second = client.get(
        "/api/v1/notes",
        params={"page": 2, "per_page": 12},
        headers=headers,
    ).json()

    assert first["meta"] == {
        "page": 1,
        "per_page": 12,
        "total": 15,
        "total_pages": 2,
    }
    assert first["data"][0]["id"] == pinned["id"]
    assert first["data"][0]["is_pinned"] is True
    assert len(first["data"]) == 12
    assert len(second["data"]) == 3
    # A listagem devolve prévia, não o conteúdo inteiro.
    assert "preview" in first["data"][0]
    assert "content" not in first["data"][0]


def test_filters_by_search_and_pinned(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    alpha = _create(client, headers, title="Receita de bolo", content="Farinha")
    beta = _create(client, headers, title="Ideias", content="Comprar farinha")
    client.patch(
        f"/api/v1/notes/{beta['id']}",
        json={"is_pinned": True},
        headers=headers,
    )

    by_title = client.get(
        "/api/v1/notes", params={"q": "bolo"}, headers=headers
    ).json()
    by_content = client.get(
        "/api/v1/notes", params={"q": "farinha"}, headers=headers
    ).json()
    pinned = client.get(
        "/api/v1/notes", params={"pinned": "true"}, headers=headers
    ).json()
    unpinned = client.get(
        "/api/v1/notes", params={"pinned": "false"}, headers=headers
    ).json()

    assert [item["id"] for item in by_title["data"]] == [alpha["id"]]
    assert {item["id"] for item in by_content["data"]} == {
        alpha["id"],
        beta["id"],
    }
    assert [item["id"] for item in pinned["data"]] == [beta["id"]]
    assert [item["id"] for item in unpinned["data"]] == [alpha["id"]]


def test_notes_are_isolated_by_user(
    client: TestClient, admin_auth: dict, user_auth: dict
) -> None:
    note = _create(client, auth_headers(user_auth))

    other_headers = auth_headers(admin_auth)
    hidden = client.get(f"/api/v1/notes/{note['id']}", headers=other_headers)
    listed = client.get("/api/v1/notes", headers=other_headers).json()

    assert hidden.status_code == 404
    assert hidden.json()["code"] == "NOTE_NOT_FOUND"
    assert listed["data"] == []
    assert listed["meta"]["total"] == 0


def test_secret_reads_notes_within_its_level(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    public_note = _create(client, headers, title="Pública")
    secret_note = _create(
        client, headers, title="Sigilosa", sensitivity="sigiloso"
    )

    response = client.post(
        "/api/v1/secrets",
        json={
            "name": "notas",
            "permissions": {
                "notas": {"read": "complexo", "create": True, "write": False}
            },
        },
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    token_headers = {"Authorization": f"Bearer {response.json()['data']['token']}"}

    listed = client.get("/api/v1/notes", headers=token_headers).json()
    assert [item["id"] for item in listed["data"]] == [public_note["id"]]
    assert listed["meta"]["total"] == 1

    hidden = client.get(f"/api/v1/notes/{secret_note['id']}", headers=token_headers)
    assert hidden.status_code == 404

    created = client.post(
        "/api/v1/notes",
        json={"content": "Criada pela credencial"},
        headers=token_headers,
    )
    assert created.status_code == 201

    denied = client.patch(
        f"/api/v1/notes/{created.json()['data']['id']}",
        json={"content": "Alterada"},
        headers=token_headers,
    )
    assert denied.status_code == 403
    assert denied.json()["code"] == "WRITE_NOT_PERMITTED"
