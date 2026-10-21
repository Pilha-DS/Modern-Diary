"""Cria as notas livres e libera a área de notas para credenciais.

Revision ID: 0007
Revises: 0006
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0007"
down_revision: str | None = "0006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

OLD_AREA_VALUES = ("KNOWLEDGE", "GOAL", "DAY", "ACTIVITY")
AREA_VALUES = ("KNOWLEDGE", "NOTE", "GOAL", "DAY", "ACTIVITY")


def upgrade() -> None:
    op.create_table(
        "notes",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=True),
        sa.Column("content", mysql.LONGTEXT(), nullable=False),
        sa.Column(
            "is_pinned",
            sa.Boolean(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "sensitivity",
            sa.Integer(),
            server_default=sa.text("1"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_notes_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_notes"),
    )
    op.create_index("ix_notes_user_updated", "notes", ["user_id", "updated_at"])
    op.create_index(
        "ix_notes_user_sensitivity",
        "notes",
        ["user_id", "sensitivity"],
    )
    op.create_index(
        "ix_notes_user_pinned_updated",
        "notes",
        ["user_id", "is_pinned", "updated_at"],
    )
    # Busca no título e no conteúdo sem varrer a tabela.
    op.create_index(
        "ix_notes_search",
        "notes",
        ["title", "content"],
        mysql_prefix="FULLTEXT",
    )

    for table in ("secret_area_permissions", "secret_audit_logs"):
        op.alter_column(
            table,
            "area",
            existing_type=sa.Enum(*OLD_AREA_VALUES, name="secret_area"),
            type_=sa.Enum(*AREA_VALUES, name="secret_area"),
            existing_nullable=False,
        )


def downgrade() -> None:
    # A área de notas sai do enum; as linhas que a usam precisam sair antes.
    op.execute("DELETE FROM secret_area_permissions WHERE area = 'NOTE'")
    op.execute("DELETE FROM secret_audit_logs WHERE area = 'NOTE'")
    for table in ("secret_area_permissions", "secret_audit_logs"):
        op.alter_column(
            table,
            "area",
            existing_type=sa.Enum(*AREA_VALUES, name="secret_area"),
            type_=sa.Enum(*OLD_AREA_VALUES, name="secret_area"),
            existing_nullable=False,
        )

    op.drop_index("ix_notes_search", table_name="notes")
    op.drop_index("ix_notes_user_pinned_updated", table_name="notes")
    op.drop_index("ix_notes_user_sensitivity", table_name="notes")
    op.drop_index("ix_notes_user_updated", table_name="notes")
    op.drop_table("notes")
