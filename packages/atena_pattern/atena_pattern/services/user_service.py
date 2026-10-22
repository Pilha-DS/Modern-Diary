from sqlalchemy.orm import Session

from atena_pattern.core.errors import AppError
from atena_pattern.models.role import Role
from atena_pattern.models.user import User
from atena_pattern.repositories.user_repository import UserRepository


class UserService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.users = UserRepository(session)

    def get_by_id(self, user_id: int) -> User:
        user = self.users.get_by_id(user_id)
        if user is None:
            raise AppError(
                code="USER_NOT_FOUND",
                message="Usuário não encontrado.",
                status_code=404,
            )
        return user

    def list_page(self, offset: int, limit: int) -> tuple[list[User], int]:
        return self.users.list_page(offset, limit)

    def update_role(self, target_user_id: int, role: Role) -> User:
        if role is Role.ADMIN:
            raise AppError(
                code="ADMIN_ROLE_FIXED",
                message="A conta ADMIN é criada no primeiro cadastro e não pode ser atribuída.",
                status_code=409,
            )

        user = self.get_by_id(target_user_id)

        if user.role is Role.ADMIN:
            raise AppError(
                code="ADMIN_ROLE_FIXED",
                message="A conta ADMIN não pode ter a role alterada.",
                status_code=409,
            )

        user.role = role
        self.session.commit()
        return user
