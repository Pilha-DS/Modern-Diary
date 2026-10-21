"""Cria tags, ligações de tags e vínculo entre conhecimentos e metas.

Revision ID: 0005
Revises: 0004
Create Date: 2026-10-20

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0005"
down_revision: str | None = "0004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "tags",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=40), nullable=False),
        sa.Column("color", sa.String(length=7), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
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
            name="fk_tags_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_tags"),
        sa.UniqueConstraint("user_id", "name", name="uq_tags_user_name"),
    )

    op.create_table(
        "tag_links",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("tag_id", sa.Integer(), nullable=False),
        sa.Column(
            "target_type",
            sa.Enum("KNOWLEDGE", "GOAL", "AGENDA_DAY", name="tag_target"),
            nullable=False,
        ),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["tag_id"],
            ["tags.id"],
            name="fk_tag_links_tag_id_tags",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_tag_links"),
        sa.UniqueConstraint(
            "tag_id",
            "target_type",
            "target_id",
            name="uq_tag_links_target",
        ),
    )
    op.create_index(
        "ix_tag_links_target",
        "tag_links",
        ["target_type", "target_id"],
    )

    op.create_table(
        "knowledge_goal_links",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("goal_id", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["item_id"],
            ["knowledge_items.id"],
            name="fk_knowledge_goal_links_item_id_knowledge_items",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["goal_id"],
            ["goals.id"],
            name="fk_knowledge_goal_links_goal_id_goals",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_knowledge_goal_links"),
        sa.UniqueConstraint(
            "item_id",
            "goal_id",
            name="uq_knowledge_goal_links_pair",
        ),
    )
    op.create_index(
        "ix_knowledge_goal_links_goal",
        "knowledge_goal_links",
        ["goal_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_knowledge_goal_links_goal",
        table_name="knowledge_goal_links",
    )
    op.drop_table("knowledge_goal_links")
    op.drop_index("ix_tag_links_target", table_name="tag_links")
    op.drop_table("tag_links")
    op.drop_table("tags")
