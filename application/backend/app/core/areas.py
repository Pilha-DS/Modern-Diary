"""Áreas do Modern Diary que podem ser liberadas para uma credencial.

Aqui ficam as duas pontas do domínio: o enum com o valor usado na API e o
registro da coluna de sensibilidade de cada área no motor de permissões. Uma área
nova entra neste arquivo; o motor (`atena_pattern.core.access`) não muda.
"""

from enum import StrEnum

from atena_pattern.core.access import areas

from app.models.agenda import AgendaActivity, AgendaDay
from app.models.goal import Goal
from app.models.knowledge import KnowledgeItem
from app.models.note import Note


class Area(StrEnum):
    """Área do sistema que pode ser liberada para uma secret."""

    KNOWLEDGE = "conhecimentos"
    NOTE = "notas"
    GOAL = "metas"
    DAY = "dias"
    ACTIVITY = "atividades"


def register_areas() -> None:
    """Registra a coluna de sensibilidade de cada área. Roda no boot do app."""
    areas.register(Area.KNOWLEDGE.value, KnowledgeItem.sensitivity)
    areas.register(Area.NOTE.value, Note.sensitivity)
    areas.register(Area.GOAL.value, Goal.sensitivity)
    areas.register(Area.DAY.value, AgendaDay.sensitivity)
    areas.register(Area.ACTIVITY.value, AgendaActivity.sensitivity)
