import os
from collections.abc import Iterator

import pytest

os.environ["ENVIRONMENT"] = "test"
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["SECRET_KEY"] = "test-secret-key-with-at-least-32-characters"
os.environ["ACCESS_TOKEN_EXPIRE_MINUTES"] = "60"

from fastapi.testclient import TestClient  # noqa: E402
from sqlalchemy import create_engine  # noqa: E402
from sqlalchemy.orm import Session, sessionmaker  # noqa: E402
from sqlalchemy.pool import StaticPool  # noqa: E402

from atena_pattern.core.database import Base, get_db  # noqa: E402
from app.main import app  # noqa: E402
from atena_pattern.models.system_state import SystemState  # noqa: E402

engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionFactory = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


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
