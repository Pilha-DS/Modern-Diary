"""Cria usuários, roles e o estado inicial do sistema.

Revision ID: 0001
Revises:
Create Date: 2026-10-19

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("username", sa.String(length=32), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column(
            "role",
            sa.Enum("ADMIN", "MODERATOR", "USER", name="user_role"),
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
        sa.PrimaryKeyConstraint("id", name="pk_users"),
        sa.UniqueConstraint("username", name="uq_users_username"),
    )

    op.create_table(
        "system_state",
        sa.Column("id", sa.Integer(), autoincrement=False, nullable=False),
        sa.Column("admin_created", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_system_state"),
    )

    system_state = sa.table(
        "system_state",
        sa.column("id", sa.Integer()),
        sa.column("admin_created", sa.Boolean()),
    )
    op.bulk_insert(system_state, [{"id": 1, "admin_created": False}])


def downgrade() -> None:
    op.drop_table("system_state")
    op.drop_table("users")
