"""Cria a agenda: nota do dia e atividades.

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-19

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0002"
down_revision: str | None = "0001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "agenda_days",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("note", sa.Text(), nullable=True),
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
            name="fk_agenda_days_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_agenda_days"),
        sa.UniqueConstraint("user_id", "day", name="uq_agenda_days_user_day"),
    )

    op.create_table(
        "agenda_activities",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("start_time", sa.Time(), nullable=True),
        sa.Column(
            "priority",
            sa.Enum("LOW", "MEDIUM", "HIGH", name="agenda_priority"),
            nullable=False,
        ),
        sa.Column("is_done", sa.Boolean(), server_default=sa.text("0"), nullable=False),
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
            name="fk_agenda_activities_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_agenda_activities"),
    )
    op.create_index(
        "ix_agenda_activities_user_day",
        "agenda_activities",
        ["user_id", "day"],
    )


def downgrade() -> None:
    op.drop_index("ix_agenda_activities_user_day", table_name="agenda_activities")
    op.drop_table("agenda_activities")
    op.drop_table("agenda_days")
