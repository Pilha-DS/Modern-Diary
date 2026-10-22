"""Modelos do Modern Diary.

Importar este pacote registra no metadata do núcleo (`atena_pattern.Base`) as
tabelas do projeto e as tabelas herdadas, na ordem em que as chaves estrangeiras
precisam existir.
"""

# Núcleo: usuários, papéis, credenciais, sensibilidade e estado do sistema.
import atena_pattern.models  # noqa: F401

from app.core.areas import Area  # noqa: F401  (áreas do projeto)
from app.models.agenda import AgendaActivity, AgendaDay, AgendaNote, Priority
from app.models.audit import AuditArea, AuditEvent, AuditKind
from app.models.country import Country
from app.models.goal import Goal, GoalStatus, GoalStep
from app.models.holiday import Holiday
from app.models.knowledge import (
    KnowledgeAttachment,
    KnowledgeGoalLink,
    KnowledgeItem,
    KnowledgeObservation,
    KnowledgeRelation,
)
from app.models.life_link import EntityLink, LinkType
from app.models.note import Note
from app.models.tag import Tag, TagLink, TagTarget

__all__ = [
    "AgendaActivity",
    "AgendaDay",
    "AgendaNote",
    "Area",
    "AuditArea",
    "AuditEvent",
    "AuditKind",
    "Country",
    "EntityLink",
    "Goal",
    "GoalStatus",
    "GoalStep",
    "Holiday",
    "KnowledgeAttachment",
    "KnowledgeGoalLink",
    "KnowledgeItem",
    "KnowledgeObservation",
    "KnowledgeRelation",
    "LinkType",
    "Note",
    "Priority",
    "Tag",
    "TagLink",
    "TagTarget",
]
