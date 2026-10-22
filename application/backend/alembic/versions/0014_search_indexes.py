"""Índices de texto completo da pesquisa universal.

Revision ID: 0014
Revises: 0013
Create Date: 2026-10-21

"""
from collections.abc import Sequence

from alembic import op

revision: str = "0014"
down_revision: str | None = "0013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

# Notas já têm o índice desde a 0007.
_INDEXES = (
    ("ix_knowledge_items_search", "knowledge_items", ["title", "content"]),
    ("ix_goals_search", "goals", ["title", "description"]),
    ("ix_agenda_notes_search", "agenda_notes", ["content"]),
    ("ix_agenda_activities_search", "agenda_activities", ["title"]),
)


def upgrade() -> None:
    for name, table, columns in _INDEXES:
        op.create_index(name, table, columns, mysql_prefix="FULLTEXT")


def downgrade() -> None:
    for name, table, _ in _INDEXES:
        op.drop_index(name, table_name=table)
