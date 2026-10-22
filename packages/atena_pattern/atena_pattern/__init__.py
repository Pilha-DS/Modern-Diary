"""Núcleo reutilizável dos projetos do ecossistema Atena.

O pacote entrega o que não é de domínio: envelope único de resposta, erros,
paginação, identificação da requisição, sessão JWT, credenciais de integração,
níveis de sensibilidade e o motor de permissões por área.
"""

from atena_pattern.app import create_app
from atena_pattern.core.access import AccessGuard, Actor, AreaRegistry, areas
from atena_pattern.core.config import AthenaSettings, configure, get_settings
from atena_pattern.core.database import Base, configure_database, get_db
from atena_pattern.core.errors import AppError, FieldError
from atena_pattern.models.api_secret import (
    ApiSecret,
    AuditAction,
    AuditResult,
    SecretAreaPermission,
    SecretAuditLog,
)
from atena_pattern.models.role import Role
from atena_pattern.models.sensitivity import Sensitivity
from atena_pattern.models.user import User

__all__ = [
    "AccessGuard",
    "Actor",
    "ApiSecret",
    "AppError",
    "AreaRegistry",
    "AthenaSettings",
    "AuditAction",
    "AuditResult",
    "Base",
    "FieldError",
    "Role",
    "SecretAreaPermission",
    "SecretAuditLog",
    "Sensitivity",
    "User",
    "areas",
    "configure",
    "configure_database",
    "create_app",
    "get_db",
    "get_settings",
]

__version__ = "0.1.0"
