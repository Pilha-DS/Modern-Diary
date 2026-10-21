"""Cria a tabela holiday, com os feriados guardados por usuário.

Revision ID: 0009
Revises: 0008
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0009"
down_revision: str | None = "0008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "holiday",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("country_iso2", sa.CHAR(2), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column("name", sa.String(length=160), nullable=False),
        sa.Column("local_name", sa.String(length=160), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_holiday_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_holiday"),
        sa.UniqueConstraint(
            "user_id",
            "country_iso2",
            "day",
            "name",
            name="uq_holiday_user_country_day_name",
        ),
    )
    op.create_index("ix_holiday_user_day", "holiday", ["user_id", "day"])


def downgrade() -> None:
    op.drop_index("ix_holiday_user_day", table_name="holiday")
    op.drop_table("holiday")
