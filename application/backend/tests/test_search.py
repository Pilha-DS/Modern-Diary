from fastapi.testclient import TestClient

from tests.conftest import auth_headers

TERM = "orvalho"


def _search(client: TestClient, headers: dict, **params) -> dict:
    response = client.get("/api/v1/search", params=params, headers=headers)
    assert response.status_code == 200, response.json()
    return response.json()


def _knowledge(
    client: TestClient,
    headers: dict,
    title: str,
    *,
    content: str | None = None,
    sensitivity: str = "publico",
    tag_ids: list[int] | None = None,
) -> dict:
    response = client.post(
        "/api/v1/knowledge",
        json={
            "title": title,
            "content": content,
            "sensitivity": sensitivity,
            "tag_ids": tag_ids or [],
        },
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _goal(client: TestClient, headers: dict, title: str, **extra) -> dict:
    response = client.post(
        "/api/v1/goals",
        json={"title": title, **extra},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _note(client: TestClient, headers: dict, title: str) -> dict:
    response = client.post(
        "/api/v1/notes",
        json={"title": title, "content": "texto"},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def _agenda_note(client: TestClient, headers: dict, day: str, content: str) -> dict:
    response = client.post(
        f"/api/v1/agenda/days/{day}/notes",
        json={"content": content},
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


def _tag(client: TestClient, headers: dict, name: str) -> dict:
    response = client.post(
        "/api/v1/tags",
        json={"name": name, "color": "#3A7D6C"},
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def test_search_requires_authentication(client: TestClient) -> None:
    response = client.get("/api/v1/search", params={"q": TERM})

    assert response.status_code == 401


def test_search_finds_every_area(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    _knowledge(client, headers, f"Nota sobre {TERM}", content=f"estudo de {TERM}")
    _goal(client, headers, f"Meta {TERM}")
    _note(client, headers, f"Rascunho {TERM}")
    _agenda_note(client, headers, "2026-03-10", f"o {TERM} de hoje")
    _activity(client, headers, "2026-03-10", f"Correr no {TERM}")

    envelope = _search(client, headers, q=TERM)

    assert envelope["code"] == "SEARCH_RESULTS"
    assert {result["type"] for result in envelope["data"]} == {
        "knowledge",
        "goal",
        "note",
        "agenda_note",
        "activity",
    }
    assert envelope["meta"]["total"] == 5
    agenda_note = next(
        result for result in envelope["data"] if result["type"] == "agenda_note"
    )
    assert agenda_note["day"] == "2026-03-10"
    assert agenda_note["snippet"].startswith("o orvalho")


def test_search_filters_by_type_sensitivity_and_period(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    _knowledge(client, headers, f"{TERM} aberto")
    _knowledge(client, headers, f"{TERM} sigiloso", sensitivity="sigiloso")
    _activity(client, headers, "2026-03-10", f"{TERM} antigo")
    _activity(client, headers, "2026-03-12", f"{TERM} novo")

    only_knowledge = _search(client, headers, q=TERM, types="knowledge")
    assert {result["type"] for result in only_knowledge["data"]} == {"knowledge"}
    assert only_knowledge["meta"]["total"] == 2

    public_only = _search(
        client, headers, q=TERM, types="knowledge", sensitivity="publico"
    )
    assert [result["title"] for result in public_only["data"]] == [f"{TERM} aberto"]

    in_period = _search(
        client,
        headers,
        q=TERM,
        types="activity",
        **{"from": "2026-03-11", "to": "2026-03-31"},
    )
    assert [result["title"] for result in in_period["data"]] == [f"{TERM} novo"]


def test_search_with_tag_covers_only_tagged_areas(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    tag = _tag(client, headers, "estudo")
    _knowledge(client, headers, f"{TERM} com tag", tag_ids=[tag["id"]])
    _knowledge(client, headers, f"{TERM} sem tag")
    _note(client, headers, f"{TERM} em nota")

    envelope = _search(client, headers, q=TERM, tag_id=tag["id"])

    assert [result["title"] for result in envelope["data"]] == [f"{TERM} com tag"]


def test_search_respects_secret_read_level(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    _knowledge(client, headers, f"{TERM} publico")
    _knowledge(client, headers, f"{TERM} sigiloso", sensitivity="sigiloso")
    secret = client.post(
        "/api/v1/secrets",
        json={
            "name": "leitor",
            "permissions": {
                "conhecimentos": {"read": "basico", "create": False, "write": False}
            },
        },
        headers=headers,
    ).json()["data"]

    envelope = _search(
        client,
        {"Authorization": f"Bearer {secret['token']}"},
        q=TERM,
    )

    assert [result["title"] for result in envelope["data"]] == [f"{TERM} publico"]
    assert envelope["meta"]["total"] == 1


def test_search_rejects_unknown_filters(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)

    invalid_type = client.get(
        "/api/v1/search", params={"q": TERM, "types": "diario"}, headers=headers
    )
    invalid_level = client.get(
        "/api/v1/search",
        params={"q": TERM, "sensitivity": "secreto"},
        headers=headers,
    )

    assert invalid_type.status_code == 422
    assert invalid_type.json()["code"] == "SEARCH_INVALID_TYPE"
    assert invalid_level.status_code == 422
    assert invalid_level.json()["code"] == "SEARCH_INVALID_SENSITIVITY"


def test_search_paginates_in_the_database(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    for index in range(3):
        _note(client, headers, f"{TERM} {index}")

    first = _search(client, headers, q=TERM, per_page=2)
    second = _search(client, headers, q=TERM, per_page=2, page=2)

    assert len(first["data"]) == 2
    assert first["meta"] == {
        "page": 1,
        "per_page": 2,
        "total": 3,
        "total_pages": 2,
    }
    assert len(second["data"]) == 1
    assert {result["ref"] for result in first["data"]}.isdisjoint(
        {result["ref"] for result in second["data"]}
    )
