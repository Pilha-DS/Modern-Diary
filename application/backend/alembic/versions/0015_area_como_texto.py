"""Área da credencial vira texto livre, definida pelo projeto.

O motor de permissões passou a viver em `atena_pattern` e não conhece o domínio:
cada projeto registra as próprias áreas. A coluna deixa de ser um ENUM do MySQL
(que exigia migration para cada área nova) e passa a ser `VARCHAR(48)`.

Revision ID: 0015
Revises: 0014
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0015"
down_revision: str | None = "0014"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Valores que existiam no ENUM antes desta migration.
AREA_VALUES = ("conhecimentos", "notas", "metas", "dias", "atividades")

_TABLES = ("secret_area_permissions", "secret_audit_logs")


def upgrade() -> None:
    for table in _TABLES:
        op.alter_column(
            table,
            "area",
            existing_type=sa.Enum(*AREA_VALUES, name="secret_area"),
            type_=sa.String(48),
            existing_nullable=False,
        )


def downgrade() -> None:
    for table in _TABLES:
        op.alter_column(
            table,
            "area",
            existing_type=sa.String(48),
            type_=sa.Enum(*AREA_VALUES, name="secret_area"),
            existing_nullable=False,
        )
