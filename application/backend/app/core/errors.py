from dataclasses import dataclass, field


@dataclass
class FieldError:
    field: str
    code: str
    message: str


@dataclass
class AppError(Exception):
    code: str
    message: str
    status_code: int
    errors: list[FieldError] = field(default_factory=list)
