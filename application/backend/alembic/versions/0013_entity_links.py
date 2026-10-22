"""Cria as ligações livres entre registros (grafo de vida).

Revision ID: 0013
Revises: 0012
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0013"
down_revision: str | None = "0012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "entity_links",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column(
            "source_type",
            sa.Enum(
                "KNOWLEDGE",
                "GOAL",
                "NOTE",
                "ACTIVITY",
                "DAY",
                name="entity_link_type",
            ),
            nullable=False,
        ),
        sa.Column("source_ref", sa.String(length=40), nullable=False),
        sa.Column(
            "target_type",
            sa.Enum(
                "KNOWLEDGE",
                "GOAL",
                "NOTE",
                "ACTIVITY",
                "DAY",
                name="entity_link_type",
            ),
            nullable=False,
        ),
        sa.Column("target_ref", sa.String(length=40), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_entity_links_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_entity_links"),
        sa.UniqueConstraint(
            "user_id",
            "source_type",
            "source_ref",
            "target_type",
            "target_ref",
            name="uq_entity_links_pair",
        ),
    )
    op.create_index(
        "ix_entity_links_user_target",
        "entity_links",
        ["user_id", "target_type", "target_ref"],
    )


def downgrade() -> None:
    op.drop_table("entity_links")
