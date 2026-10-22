"""Rotas do domínio do Modern Diary.

Autenticação, usuários e credenciais não aparecem aqui: vêm do núcleo em
`atena_pattern` e entram sob o mesmo prefixo `/api/v1`.
"""

from fastapi import APIRouter

from app.api.routes import (
    agenda,
    audit,
    countries,
    goals,
    holidays,
    knowledge,
    life,
    notes,
    search,
    tags,
)

api_router = APIRouter()
api_router.include_router(audit.router)
api_router.include_router(agenda.router)
api_router.include_router(notes.router)
api_router.include_router(goals.router)
api_router.include_router(knowledge.router)
api_router.include_router(life.router)
api_router.include_router(search.router)
api_router.include_router(tags.router)
api_router.include_router(countries.router)
api_router.include_router(holidays.router)
