"""Montagem da aplicação.

O núcleo vem de `atena_pattern` (envelope, sessão, usuários, credenciais). Aqui
só entram as rotas do domínio do Modern Diary.
"""

from atena_pattern import create_app

from app.api.router import api_router
from app.core.areas import register_areas
from app.core.config import Settings

register_areas()

app = create_app(Settings(), routers=[api_router], title="Modern Diary API")
