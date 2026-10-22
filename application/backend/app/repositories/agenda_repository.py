from datetime import date

from sqlalchemy import case, delete, func, select
from sqlalchemy.orm import Session

from app.models.agenda import AgendaActivity, AgendaDay, AgendaNote, Priority
from atena_pattern.models.sensitivity import Sensitivity


class AgendaRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_day(
        self, user_id: int, day: date, criteria: list | None = None
    ) -> AgendaDay | None:
        return self.session.scalar(
            select(AgendaDay).where(
                AgendaDay.user_id == user_id,
                AgendaDay.day == day,
                *(criteria or []),
            )
        )

    def note_days(
        self,
        user_id: int,
        start: date,
        end: date,
        criteria: list | None = None,
    ) -> list[date]:
        return list(
            self.session.scalars(
                select(AgendaNote.day)
                .where(
                    AgendaNote.user_id == user_id,
                    AgendaNote.day >= start,
                    AgendaNote.day <= end,
                    func.length(func.trim(AgendaNote.content)) > 0,
                    *(criteria or []),
                )
                .distinct()
                .order_by(AgendaNote.day)
            ).all()
        )

    def list_notes(
        self,
        user_id: int,
        day: date,
        criteria: list | None = None,
    ) -> list[AgendaNote]:
        return list(
            self.session.scalars(
                select(AgendaNote)
                .where(
                    AgendaNote.user_id == user_id,
                    AgendaNote.day == day,
                    *(criteria or []),
                )
                .order_by(AgendaNote.created_at, AgendaNote.id)
            ).all()
        )

    def get_note(
        self, user_id: int, note_id: int, criteria: list | None = None
    ) -> AgendaNote | None:
        return self.session.scalar(
            select(AgendaNote).where(
                AgendaNote.id == note_id,
                AgendaNote.user_id == user_id,
                *(criteria or []),
            )
        )

    def count_notes(self, user_id: int, day: date) -> int:
        return (
            self.session.scalar(
                select(func.count(AgendaNote.id)).where(
                    AgendaNote.user_id == user_id,
                    AgendaNote.day == day,
                )
            )
            or 0
        )

    def day_levels(
        self, user_id: int, start: date, end: date
    ) -> dict[date, Sensitivity]:
        """Nível de cada dia com registro no período, para filtrar metadados."""
        rows = self.session.execute(
            select(AgendaDay.day, AgendaDay.sensitivity).where(
                AgendaDay.user_id == user_id,
                AgendaDay.day >= start,
                AgendaDay.day <= end,
            )
        ).all()
        return {day: level for day, level in rows}

    def activity_totals(
        self,
        user_id: int,
        start: date,
        end: date,
        criteria: list | None = None,
    ) -> list[tuple[date, int, int, int]]:
        rows = self.session.execute(
            select(
                AgendaActivity.day,
                func.count(AgendaActivity.id),
                func.sum(case((AgendaActivity.is_done.is_(True), 1), else_=0)),
                func.max(
                    case(
                        (AgendaActivity.priority == Priority.HIGH, 2),
                        (AgendaActivity.priority == Priority.MEDIUM, 1),
                        else_=0,
                    )
                ),
            )
            .where(
                AgendaActivity.user_id == user_id,
                AgendaActivity.day >= start,
                AgendaActivity.day <= end,
                *(criteria or []),
            )
            .group_by(AgendaActivity.day)
            .order_by(AgendaActivity.day)
        ).all()
        return [(day, int(total), int(done), int(rank)) for day, total, done, rank in rows]

    def list_activities(
        self,
        user_id: int,
        day: date,
        criteria: list | None = None,
    ) -> list[AgendaActivity]:
        return list(
            self.session.scalars(
                select(AgendaActivity)
                .where(
                    AgendaActivity.user_id == user_id,
                    AgendaActivity.day == day,
                    *(criteria or []),
                )
                .order_by(
                    AgendaActivity.start_time.is_(None),
                    AgendaActivity.start_time,
                    AgendaActivity.id,
                )
            ).all()
        )

    def count_activities(self, user_id: int, day: date) -> int:
        return (
            self.session.scalar(
                select(func.count(AgendaActivity.id)).where(
                    AgendaActivity.user_id == user_id,
                    AgendaActivity.day == day,
                )
            )
            or 0
        )

    def get_activity(
        self, user_id: int, activity_id: int, criteria: list | None = None
    ) -> AgendaActivity | None:
        return self.session.scalar(
            select(AgendaActivity).where(
                AgendaActivity.id == activity_id,
                AgendaActivity.user_id == user_id,
                *(criteria or []),
            )
        )

    def add(self, row: AgendaDay | AgendaNote | AgendaActivity) -> None:
        self.session.add(row)

    def remove(self, row: AgendaActivity | AgendaNote) -> None:
        self.session.delete(row)

    def delete_day(self, user_id: int, day: date) -> None:
        self.session.execute(
            delete(AgendaDay).where(
                AgendaDay.user_id == user_id,
                AgendaDay.day == day,
            )
        )
