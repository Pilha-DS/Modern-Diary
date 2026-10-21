from fastapi.testclient import TestClient

from tests.conftest import auth_headers


def _create_goal(
    client: TestClient,
    headers: dict,
    *,
    title: str = "Aprender Flutter",
    steps: list[str] | None = None,
    description: str | None = None,
    due_date: str | None = None,
) -> dict:
    response = client.post(
        "/api/v1/goals",
        json={
            "title": title,
            "description": description,
            "due_date": due_date,
            "steps": [{"title": step} for step in steps or []],
        },
        headers=headers,
    )
    assert response.status_code == 201, response.json()
    return response.json()["data"]


def test_goals_require_authentication(client: TestClient) -> None:
    response = client.get("/api/v1/goals")

    assert response.status_code == 401
    assert response.json()["code"] == "UNAUTHORIZED"


def test_creates_goal_with_steps(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)

    data = _create_goal(
        client,
        headers,
        title="  Aprender Flutter  ",
        description="  Do zero ao deploy  ",
        due_date="2026-12-31",
        steps=["Instalar", "Primeiro app"],
    )

    assert data["title"] == "Aprender Flutter"
    assert data["description"] == "Do zero ao deploy"
    assert data["due_date"] == "2026-12-31"
    assert data["is_completed"] is False
    assert data["is_archived"] is False
    assert data["progress_done"] == 0
    assert data["progress_total"] == 2
    assert [step["title"] for step in data["steps"]] == ["Instalar", "Primeiro app"]


def test_goal_without_steps_counts_the_goal_itself(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    goal = _create_goal(client, headers)

    assert goal["progress_done"] == 0
    assert goal["progress_total"] == 1


def test_step_progress_updates(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    goal = _create_goal(client, headers, steps=["Um", "Dois"])
    first_step = goal["steps"][0]

    response = client.patch(
        f"/api/v1/goals/{goal['id']}/steps/{first_step['id']}",
        json={"is_done": True},
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["code"] == "GOAL_STEP_UPDATED"
    assert response.json()["data"]["is_done"] is True

    listed = client.get("/api/v1/goals", headers=headers).json()["data"]
    assert listed[0]["progress_done"] == 1
    assert listed[0]["progress_total"] == 2


def test_completes_and_reopens_goal(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    goal = _create_goal(client, headers)

    completed = client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"is_completed": True},
        headers=headers,
    ).json()["data"]

    assert completed["is_completed"] is True
    assert completed["progress_done"] == 1
    assert completed["progress_total"] == 1

    active = client.get(
        "/api/v1/goals", params={"status": "ACTIVE"}, headers=headers
    ).json()
    completed_list = client.get(
        "/api/v1/goals", params={"status": "COMPLETED"}, headers=headers
    ).json()

    assert active["data"] == []
    assert active["meta"]["counts"] == {"ACTIVE": 0, "COMPLETED": 1, "ARCHIVED": 0}
    assert [item["id"] for item in completed_list["data"]] == [goal["id"]]

    reopened = client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"is_completed": False},
        headers=headers,
    ).json()["data"]

    assert reopened["is_completed"] is False
    assert reopened["progress_done"] == 0


def test_archives_goal_and_keeps_completion(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    goal = _create_goal(client, headers)
    client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"is_completed": True},
        headers=headers,
    )

    archived = client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"is_archived": True},
        headers=headers,
    ).json()["data"]

    assert archived["is_archived"] is True
    assert archived["is_completed"] is True

    active = client.get(
        "/api/v1/goals", params={"status": "ACTIVE"}, headers=headers
    ).json()
    archived_list = client.get(
        "/api/v1/goals", params={"status": "ARCHIVED"}, headers=headers
    ).json()

    assert active["data"] == []
    assert archived_list["meta"]["counts"] == {
        "ACTIVE": 0,
        "COMPLETED": 0,
        "ARCHIVED": 1,
    }
    assert [item["id"] for item in archived_list["data"]] == [goal["id"]]

    restored = client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"is_archived": False},
        headers=headers,
    ).json()["data"]
    assert restored["is_archived"] is False


def test_lists_twelve_goals_per_page(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    for index in range(14):
        _create_goal(client, headers, title=f"Meta {index:02d}")

    first = client.get(
        "/api/v1/goals",
        params={"page": 1, "per_page": 12},
        headers=headers,
    ).json()
    second = client.get(
        "/api/v1/goals",
        params={"page": 2, "per_page": 12},
        headers=headers,
    ).json()

    assert len(first["data"]) == 12
    assert first["meta"]["page"] == 1
    assert first["meta"]["per_page"] == 12
    assert first["meta"]["total"] == 14
    assert first["meta"]["total_pages"] == 2
    assert len(second["data"]) == 2


def test_deletes_goal_and_steps(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    goal = _create_goal(client, headers, steps=["Etapa"])

    response = client.delete(f"/api/v1/goals/{goal['id']}", headers=headers)

    assert response.status_code == 200
    assert response.json()["code"] == "GOAL_DELETED"

    listed = client.get("/api/v1/goals", headers=headers).json()
    assert listed["data"] == []
    assert listed["meta"]["total"] == 0

    step = client.delete(
        f"/api/v1/goals/{goal['id']}/steps/{goal['steps'][0]['id']}",
        headers=headers,
    )
    assert step.status_code == 404
    assert step.json()["code"] == "GOAL_STEP_NOT_FOUND"


def test_other_user_cannot_touch_goal(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)
    goal = _create_goal(client, headers, steps=["Etapa"])

    other = client.post(
        "/api/v1/auth/register",
        json={"username": "outro", "password": "senha1234"},
    ).json()["data"]
    other_headers = auth_headers(other)

    update = client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"is_completed": True},
        headers=other_headers,
    )
    delete = client.delete(f"/api/v1/goals/{goal['id']}", headers=other_headers)
    step = client.patch(
        f"/api/v1/goals/{goal['id']}/steps/{goal['steps'][0]['id']}",
        json={"is_done": True},
        headers=other_headers,
    )

    assert update.status_code == 404
    assert delete.status_code == 404
    assert step.status_code == 404
    assert update.json()["code"] == "GOAL_NOT_FOUND"
    assert step.json()["code"] == "GOAL_STEP_NOT_FOUND"


def test_gets_goal_by_id_with_tags_and_steps(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    goal = _create_goal(client, headers, steps=["Um", "Dois"])
    tag = client.post(
        "/api/v1/tags",
        json={"name": "foco", "color": "#22C55E"},
        headers=headers,
    ).json()["data"]
    client.patch(
        f"/api/v1/goals/{goal['id']}",
        json={"tag_ids": [tag["id"]]},
        headers=headers,
    )

    response = client.get(f"/api/v1/goals/{goal['id']}", headers=headers)

    assert response.status_code == 200
    data = response.json()["data"]
    assert response.json()["code"] == "GOAL_FOUND"
    assert data["id"] == goal["id"]
    assert data["progress_total"] == 2
    assert [step["title"] for step in data["steps"]] == ["Um", "Dois"]
    assert [entry["name"] for entry in data["tags"]] == ["foco"]


def test_goal_detail_of_another_user_is_not_found(
    client: TestClient, user_auth: dict
) -> None:
    headers = auth_headers(user_auth)
    goal = _create_goal(client, headers)
    other = client.post(
        "/api/v1/auth/register",
        json={"username": "curioso", "password": "senha1234"},
    ).json()["data"]

    response = client.get(
        f"/api/v1/goals/{goal['id']}",
        headers=auth_headers(other),
    )

    assert response.status_code == 404
    assert response.json()["code"] == "GOAL_NOT_FOUND"


def test_goal_validation(client: TestClient, user_auth: dict) -> None:
    headers = auth_headers(user_auth)

    blank = client.post("/api/v1/goals", json={"title": "   "}, headers=headers)
    too_many_steps = client.post(
        "/api/v1/goals",
        json={"title": "Grande", "steps": [{"title": f"E{i}"} for i in range(51)]},
        headers=headers,
    )
    bad_date = client.post(
        "/api/v1/goals",
        json={"title": "Data", "due_date": "31/12/2026"},
        headers=headers,
    )

    assert blank.status_code == 422
    assert blank.json()["code"] == "VALIDATION_ERROR"
    assert too_many_steps.status_code == 422
    assert too_many_steps.json()["code"] == "VALIDATION_ERROR"
    assert bad_date.status_code == 422
    assert bad_date.json()["code"] == "VALIDATION_ERROR"
