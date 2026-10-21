from pydantic import BaseModel

from app.schemas.user import UserResponse


class AuthData(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserResponse
