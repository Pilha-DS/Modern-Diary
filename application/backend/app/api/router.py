from fastapi import APIRouter

from app.api.routes import (
    agenda,
    auth,
    countries,
    goals,
    holidays,
    knowledge,
    notes,
    secrets,
    tags,
    users,
)

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(secrets.router)
api_router.include_router(agenda.router)
api_router.include_router(notes.router)
api_router.include_router(goals.router)
api_router.include_router(knowledge.router)
api_router.include_router(tags.router)
api_router.include_router(countries.router)
api_router.include_router(holidays.router)
