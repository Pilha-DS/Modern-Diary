from fastapi import APIRouter

from atena_pattern.api.routes import auth, secrets, users

#: Rotas que todo projeto herda: sessão, usuários e credenciais.
base_router = APIRouter()
base_router.include_router(auth.router)
base_router.include_router(users.router)
base_router.include_router(secrets.router)
