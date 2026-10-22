from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session
from sqlalchemy.pool import StaticPool

from atena_pattern.app import create_app
from atena_pattern.core.access import areas
from atena_pattern.core.config import AthenaSettings, configure
from atena_pattern.core.database import (
    Base,
    configure_database,
    get_db,
)
from atena_pattern.models import SystemState
from tests.sample import AREA, SampleRecord

TEST_SETTINGS = AthenaSettings(
    app_name="Atena Test",
    environment="test",
    database_url="sqlite://",
    secret_key="test-secret-key-with-at-least-32-characters",
)

configure(TEST_SETTINGS)
engine, TestingSessionFactory = configure_database(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)

#: Uma área do projeto de teste. O núcleo não conhece nenhuma área sozinho.
areas.register(AREA, SampleRecord.sensitivity)

app = create_app(TEST_SETTINGS)


@pytest.fixture
def session() -> Iterator[Session]:
    Base.metadata.create_all(engine)
    with TestingSessionFactory() as session:
        session.add(SystemState(id=1, admin_created=False))
        session.commit()
        yield session
    Base.metadata.drop_all(engine)


@pytest.fixture
def client(session: Session) -> Iterator[TestClient]:
    def override_get_db() -> Iterator[Session]:
        yield session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def admin_auth(client: TestClient) -> dict:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": "admin", "password": "admin1234"},
    )
    assert response.status_code == 201
    return response.json()["data"]


@pytest.fixture
def user_auth(client: TestClient, admin_auth: dict) -> dict:
    response = client.post(
        "/api/v1/auth/register",
        json={"username": "user", "password": "user1234"},
    )
    assert response.status_code == 201
    return response.json()["data"]


def auth_headers(auth: dict) -> dict[str, str]:
    return {"Authorization": f"Bearer {auth['access_token']}"}
