import secrets as random_secrets

import pytest
from sqlalchemy import select
from sqlalchemy.orm import Session

from atena_pattern.core.access import AccessGuard, Actor, areas
from atena_pattern.core.errors import AppError
from atena_pattern.models import (
    ApiSecret,
    AuditResult,
    SecretAreaPermission,
    SecretAuditLog,
    Sensitivity,
)
from tests.sample import AREA, SampleRecord


def _secret(
    session: Session,
    *,
    user_id: int = 1,
    read_level: Sensitivity = Sensitivity.BASIC,
    can_create: bool = False,
    can_write: bool = False,
    area: str = AREA,
) -> ApiSecret:
    secret = ApiSecret(
        user_id=user_id,
        name=f"secret-{random_secrets.token_hex(4)}",
        token_hash=random_secrets.token_hex(32),
        token_hint="abc123",
    )
    secret.permissions = [
        SecretAreaPermission(
            area=area,
            read_level=read_level,
            can_create=can_create,
            can_write=can_write,
        )
    ]
    session.add(secret)
    session.commit()
    return secret


def test_visible_filters_rows_by_read_level(session: Session) -> None:
    session.add_all(
        [
            SampleRecord(title="publico", sensitivity=Sensitivity.PUBLIC),
            SampleRecord(title="moderado", sensitivity=Sensitivity.MODERATE),
            SampleRecord(title="sigiloso", sensitivity=Sensitivity.SECRET),
        ]
    )
    session.commit()

    secret = _secret(session, read_level=Sensitivity.BASIC)
    guard = AccessGuard(session, Actor(user_id=1, secret=secret))

    rows = session.scalars(
        select(SampleRecord).where(*guard.visible(AREA)).order_by(SampleRecord.id)
    ).all()

    assert [row.title for row in rows] == ["publico"]


def test_missing_area_is_denied_and_audited(session: Session) -> None:
    secret = _secret(session)
    guard = AccessGuard(session, Actor(user_id=1, secret=secret))

    with pytest.raises(AppError) as error:
        guard.visible("area-inexistente")

    assert error.value.code == "AREA_NOT_PERMITTED"
    entry = session.scalars(select(SecretAuditLog)).one()
    assert entry.result is AuditResult.DENIED
    assert entry.area == "area-inexistente"


def test_optional_visible_returns_none_without_area(session: Session) -> None:
    secret = _secret(session)
    guard = AccessGuard(session, Actor(user_id=1, secret=secret))

    assert guard.optional_visible("area-inexistente") is None


def test_create_does_not_imply_read_or_write(session: Session) -> None:
    secret = _secret(session, can_create=True, can_write=False)
    guard = AccessGuard(session, Actor(user_id=1, secret=secret))

    guard.ensure_create(AREA, target_type="sample")
    guard.record_created(AREA, "sample", 10)

    with pytest.raises(AppError) as error:
        guard.ensure_write(
            AREA,
            Sensitivity.PUBLIC,
            target_type="sample",
            target_id=10,
        )

    assert error.value.code == "WRITE_NOT_PERMITTED"
    results = [entry.result for entry in session.scalars(select(SecretAuditLog)).all()]
    assert AuditResult.ALLOWED in results
    assert AuditResult.DENIED in results


def test_write_above_read_level_is_denied(session: Session) -> None:
    secret = _secret(
        session,
        read_level=Sensitivity.PUBLIC,
        can_write=True,
    )
    guard = AccessGuard(session, Actor(user_id=1, secret=secret))

    with pytest.raises(AppError) as error:
        guard.ensure_write(
            AREA,
            Sensitivity.SECRET,
            target_type="sample",
            target_id=1,
        )

    assert error.value.code == "WRITE_NOT_PERMITTED"


def test_new_level_above_read_level_is_denied(session: Session) -> None:
    secret = _secret(session, read_level=Sensitivity.MODERATE)
    guard = AccessGuard(session, Actor(user_id=1, secret=secret))

    guard.ensure_new_level(AREA, Sensitivity.MODERATE)

    with pytest.raises(AppError) as error:
        guard.ensure_new_level(AREA, Sensitivity.SECRET)

    assert error.value.code == "SENSITIVITY_NOT_ALLOWED"


def test_session_actor_sees_everything(session: Session) -> None:
    guard = AccessGuard(session, Actor(user_id=1))

    assert guard.visible(AREA) == []
    assert guard.read_level(AREA) is Sensitivity.ALL


def test_area_registry_only_knows_registered_areas() -> None:
    assert areas.has(AREA)
    assert not areas.has("area-inexistente")
