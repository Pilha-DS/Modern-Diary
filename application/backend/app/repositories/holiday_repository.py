from datetime import date

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.models.holiday import Holiday


class HolidayRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_between(
        self,
        user_id: int,
        start: date,
        end: date,
    ) -> list[Holiday]:
        return list(
            self.session.scalars(
                select(Holiday)
                .where(
                    Holiday.user_id == user_id,
                    Holiday.day >= start,
                    Holiday.day <= end,
                )
                .order_by(Holiday.day.asc(), Holiday.id.asc())
            ).all()
        )

    def get_on_day(self, user_id: int, day: date) -> list[Holiday]:
        return list(
            self.session.scalars(
                select(Holiday)
                .where(Holiday.user_id == user_id, Holiday.day == day)
                .order_by(Holiday.id.asc())
            ).all()
        )

    def replace_all(self, user_id: int, rows: list[Holiday]) -> None:
        """Troca os feriados do usuário: a nacionalidade é uma só."""
        self.session.execute(delete(Holiday).where(Holiday.user_id == user_id))
        self.session.add_all(rows)

    def count_for_user(self, user_id: int) -> int:
        return (
            self.session.scalar(
                select(func.count(Holiday.id)).where(Holiday.user_id == user_id)
            )
            or 0
        )
