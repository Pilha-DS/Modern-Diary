from typing import Any, Generic, TypeVar

from pydantic import BaseModel, ConfigDict

T = TypeVar("T")


class FieldErrorResponse(BaseModel):
    field: str
    code: str
    message: str


class Envelope(BaseModel, Generic[T]):
    """Forma única de resposta da API. Nenhum campo é omitido."""

    model_config = ConfigDict(from_attributes=True)

    code: str
    success: bool
    data: T | None
    message: str | None
    errors: list[FieldErrorResponse]
    meta: dict[str, Any]
    request_id: str
    timestamp: str
