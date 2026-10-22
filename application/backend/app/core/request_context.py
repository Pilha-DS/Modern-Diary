from contextvars import ContextVar, Token
from datetime import date, datetime, timedelta

_request_id: ContextVar[str] = ContextVar("request_id", default="")
_client_offset_minutes: ContextVar[int] = ContextVar(
    "client_offset_minutes", default=0
)

#: Fuso do cliente em minutos, limitado ao intervalo real da Terra.
MAX_CLIENT_OFFSET_MINUTES = 840


def set_request_id(value: str) -> Token[str]:
    return _request_id.set(value)


def reset_request_id(token: Token[str]) -> None:
    _request_id.reset(token)


def current_request_id() -> str:
    """Identificador da requisição em curso, para correlacionar com o log."""
    return _request_id.get()


def set_client_offset_minutes(value: int) -> Token[int]:
    clamped = max(-MAX_CLIENT_OFFSET_MINUTES, min(MAX_CLIENT_OFFSET_MINUTES, value))
    return _client_offset_minutes.set(clamped)


def reset_client_offset_minutes(token: Token[int]) -> None:
    _client_offset_minutes.reset(token)


def client_day(moment: datetime) -> date:
    """Dia local de quem agiu, a partir do fuso que o cliente informou."""
    return (moment + timedelta(minutes=_client_offset_minutes.get())).date()
