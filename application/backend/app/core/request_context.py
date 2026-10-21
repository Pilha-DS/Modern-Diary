from contextvars import ContextVar, Token

_request_id: ContextVar[str] = ContextVar("request_id", default="")


def set_request_id(value: str) -> Token[str]:
    return _request_id.set(value)


def reset_request_id(token: Token[str]) -> None:
    _request_id.reset(token)


def current_request_id() -> str:
    """Identificador da requisição em curso, para correlacionar com o log."""
    return _request_id.get()
