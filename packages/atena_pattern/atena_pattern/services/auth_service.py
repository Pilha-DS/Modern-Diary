from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from atena_pattern.core.errors import AppError
from atena_pattern.core.security import (
    create_access_token,
    dummy_password_hash,
    hash_password,
    verify_password,
)
from atena_pattern.models.role import Role
from atena_pattern.models.user import User
from atena_pattern.repositories.system_state_repository import SystemStateRepository
from atena_pattern.repositories.user_repository import UserRepository


class AuthService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.users = UserRepository(session)
        self.system_state = SystemStateRepository(session)

    def register(self, username: str, password: str) -> tuple[User, str, int]:
        normalized_username = username.strip().lower()

        # O lock serializa cadastros concorrentes: só o primeiro vira ADMIN.
        state = self.system_state.get_for_update()

        if self.users.get_by_username(normalized_username) is not None:
            raise AppError(
                code="USERNAME_TAKEN",
                message="Este nome de usuário já está em uso.",
                status_code=409,
            )

        role = Role.ADMIN if not state.admin_created else Role.USER
        user = User(
            username=normalized_username,
            password_hash=hash_password(password),
            role=role,
        )
        self.users.add(user)

        if role is Role.ADMIN:
            state.admin_created = True

        try:
            self.session.commit()
        except IntegrityError as error:
            self.session.rollback()
            raise AppError(
                code="USERNAME_TAKEN",
                message="Este nome de usuário já está em uso.",
                status_code=409,
            ) from error

        token, expires_in = create_access_token(user.id, user.role)
        return user, token, expires_in

    def login(self, username: str, password: str) -> tuple[User, str, int]:
        user = self.users.get_by_username(username.strip().lower())

        if user is None:
            verify_password(password, dummy_password_hash)
            raise self._invalid_credentials()

        if not verify_password(password, user.password_hash):
            raise self._invalid_credentials()

        token, expires_in = create_access_token(user.id, user.role)
        return user, token, expires_in

    @staticmethod
    def _invalid_credentials() -> AppError:
        return AppError(
            code="INVALID_CREDENTIALS",
            message="Usuário ou senha incorretos.",
            status_code=401,
        )
