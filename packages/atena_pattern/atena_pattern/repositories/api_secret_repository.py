from sqlalchemy import func, select
from sqlalchemy.orm import Session

from atena_pattern.models.api_secret import ApiSecret, SecretAuditLog, SecretAreaPermission


class ApiSecretRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get(self, user_id: int, secret_id: int) -> ApiSecret | None:
        return self.session.scalar(
            select(ApiSecret).where(
                ApiSecret.id == secret_id,
                ApiSecret.user_id == user_id,
            )
        )

    def get_by_token_hash(self, token_hash: str) -> ApiSecret | None:
        return self.session.scalar(
            select(ApiSecret).where(ApiSecret.token_hash == token_hash)
        )

    def list_page(
        self, user_id: int, offset: int, limit: int
    ) -> tuple[list[ApiSecret], int]:
        total = self.count(user_id)
        rows = list(
            self.session.scalars(
                select(ApiSecret)
                .where(ApiSecret.user_id == user_id)
                .order_by(ApiSecret.created_at.desc(), ApiSecret.id.desc())
                .offset(offset)
                .limit(limit)
            ).all()
        )
        return rows, total

    def count(self, user_id: int) -> int:
        return (
            self.session.scalar(
                select(func.count(ApiSecret.id)).where(ApiSecret.user_id == user_id)
            )
            or 0
        )

    def name_exists(
        self, user_id: int, name: str, exclude_id: int | None = None
    ) -> bool:
        criteria = [ApiSecret.user_id == user_id, ApiSecret.name == name]
        if exclude_id is not None:
            criteria.append(ApiSecret.id != exclude_id)
        found = self.session.scalar(select(ApiSecret.id).where(*criteria))
        return found is not None

    def add(self, row: ApiSecret | SecretAreaPermission | SecretAuditLog) -> None:
        self.session.add(row)

    def audit_page(
        self, user_id: int, secret_id: int, offset: int, limit: int
    ) -> tuple[list[SecretAuditLog], int]:
        criteria = [
            SecretAuditLog.user_id == user_id,
            SecretAuditLog.secret_id == secret_id,
        ]
        total = (
            self.session.scalar(
                select(func.count(SecretAuditLog.id)).where(*criteria)
            )
            or 0
        )
        rows = list(
            self.session.scalars(
                select(SecretAuditLog)
                .where(*criteria)
                .order_by(SecretAuditLog.created_at.desc(), SecretAuditLog.id.desc())
                .offset(offset)
                .limit(limit)
            ).all()
        )
        return rows, total
