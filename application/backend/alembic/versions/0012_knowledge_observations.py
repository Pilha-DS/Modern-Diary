"""Cria as observações de um conhecimento.

Revision ID: 0012
Revises: 0011
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0012"
down_revision: str | None = "0011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "knowledge_observations",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("text", sa.String(length=2000), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["item_id"],
            ["knowledge_items.id"],
            name="fk_knowledge_observations_item_id_knowledge_items",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_knowledge_observations"),
    )
    op.create_index(
        "ix_knowledge_observations_item",
        "knowledge_observations",
        ["item_id"],
    )


def downgrade() -> None:
    op.drop_table("knowledge_observations")
