from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.audit import AuditEvent


class AuditRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_day(
        self, user_id: int, day: date, offset: int, limit: int
    ) -> tuple[list[AuditEvent], int]:
        conditions = (AuditEvent.user_id == user_id, AuditEvent.day == day)
        rows = (
            self.session.scalars(
                select(AuditEvent)
                .where(*conditions)
                .order_by(AuditEvent.occurred_at.desc(), AuditEvent.id.desc())
                .offset(offset)
                .limit(limit)
            )
            .all()
        )
        total = self.session.scalar(
            select(func.count(AuditEvent.id)).where(*conditions)
        )
        return list(rows), total or 0

    def day_counts(
        self, user_id: int, start: date, end: date
    ) -> list[tuple[date, int]]:
        rows = self.session.execute(
            select(AuditEvent.day, func.count(AuditEvent.id))
            .where(
                AuditEvent.user_id == user_id,
                AuditEvent.day >= start,
                AuditEvent.day <= end,
            )
            .group_by(AuditEvent.day)
            .order_by(AuditEvent.day)
        ).all()
        return [(day, total) for day, total in rows]

    def events_for_day(
        self, user_id: int, day: date, limit: int
    ) -> list[AuditEvent]:
        return list(
            self.session.scalars(
                select(AuditEvent)
                .where(AuditEvent.user_id == user_id, AuditEvent.day == day)
                .order_by(AuditEvent.occurred_at, AuditEvent.id)
                .limit(limit)
            ).all()
        )
