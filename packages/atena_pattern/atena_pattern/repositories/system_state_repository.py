from sqlalchemy import select
from sqlalchemy.orm import Session

from atena_pattern.models.system_state import SystemState

SYSTEM_STATE_ID = 1


class SystemStateRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_for_update(self) -> SystemState:
        state = self.session.scalar(
            select(SystemState).where(SystemState.id == SYSTEM_STATE_ID).with_for_update()
        )
        if state is None:
            raise RuntimeError("Linha de estado do sistema ausente. Rode as migrations.")
        return state
