"""Cria as metas e suas etapas.

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-20

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "goals",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("due_date", sa.Date(), nullable=True),
        sa.Column(
            "status",
            sa.Enum("ACTIVE", "COMPLETED", name="goal_status"),
            nullable=False,
        ),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.Column("archived_at", sa.DateTime(), nullable=True),
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
            name="fk_goals_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_goals"),
    )
    op.create_index(
        "ix_goals_user_status_created",
        "goals",
        ["user_id", "status", "created_at"],
    )

    op.create_table(
        "goal_steps",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("goal_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("is_done", sa.Boolean(), server_default=sa.text("0"), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
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
            ["goal_id"],
            ["goals.id"],
            name="fk_goal_steps_goal_id_goals",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_goal_steps"),
    )
    op.create_index(
        "ix_goal_steps_goal_position",
        "goal_steps",
        ["goal_id", "position"],
    )


def downgrade() -> None:
    op.drop_index("ix_goal_steps_goal_position", table_name="goal_steps")
    op.drop_table("goal_steps")
    op.drop_index("ix_goals_user_status_created", table_name="goals")
    op.drop_table("goals")
