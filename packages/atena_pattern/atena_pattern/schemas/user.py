from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_serializer

from atena_pattern.models.role import Role


class RegisterRequest(BaseModel):
    username: str = Field(
        min_length=3,
        max_length=32,
        pattern=r"^[A-Za-z0-9_.-]+$",
        examples=["jonathan"],
    )
    password: str = Field(min_length=8, max_length=128, examples=["MinhaSenha123"])


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=32, examples=["jonathan"])
    password: str = Field(min_length=1, max_length=128, examples=["MinhaSenha123"])


class UpdateRoleRequest(BaseModel):
    """ADMIN não entra aqui: ele nasce no primeiro cadastro e é único."""

    role: Literal["MODERATOR", "USER"]

    def parsed_role(self) -> Role:
        return Role(self.role)


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    role: Role
    created_at: datetime

    @field_serializer("created_at")
    def serialize_created_at(self, value: datetime) -> str:
        return value.isoformat(timespec="seconds") + "Z"
