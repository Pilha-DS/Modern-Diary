from sqlalchemy import func, select
from sqlalchemy.orm import Session

from atena_pattern.models.user import User


class UserRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_by_id(self, user_id: int) -> User | None:
        return self.session.get(User, user_id)

    def get_by_username(self, username: str) -> User | None:
        return self.session.scalar(select(User).where(User.username == username))

    def add(self, user: User) -> None:
        self.session.add(user)

    def list_page(self, offset: int, limit: int) -> tuple[list[User], int]:
        total = self.session.scalar(select(func.count(User.id))) or 0
        users = list(
            self.session.scalars(
                select(User).order_by(User.id).offset(offset).limit(limit)
            ).all()
        )
        return users, total
