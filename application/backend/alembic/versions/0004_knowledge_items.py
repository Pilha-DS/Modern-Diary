"""Cria a base de conhecimentos: itens, conexões e anexos.

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-20

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0004"
down_revision: str | None = "0003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "knowledge_items",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("links", sa.JSON(), nullable=True),
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
            name="fk_knowledge_items_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_knowledge_items"),
    )
    op.create_index(
        "ix_knowledge_items_user_updated",
        "knowledge_items",
        ["user_id", "updated_at"],
    )

    op.create_table(
        "knowledge_relations",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("source_id", sa.Integer(), nullable=False),
        sa.Column("target_id", sa.Integer(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["source_id"],
            ["knowledge_items.id"],
            name="fk_knowledge_relations_source_id_knowledge_items",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["target_id"],
            ["knowledge_items.id"],
            name="fk_knowledge_relations_target_id_knowledge_items",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_knowledge_relations"),
        sa.UniqueConstraint(
            "source_id",
            "target_id",
            name="uq_knowledge_relations_pair",
        ),
    )
    op.create_index(
        "ix_knowledge_relations_target",
        "knowledge_relations",
        ["target_id"],
    )

    op.create_table(
        "knowledge_attachments",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("item_id", sa.Integer(), nullable=False),
        sa.Column("filename", sa.String(length=255), nullable=False),
        sa.Column("content_type", sa.String(length=120), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column(
            "content",
            sa.LargeBinary().with_variant(mysql.LONGBLOB(), "mysql"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["item_id"],
            ["knowledge_items.id"],
            name="fk_knowledge_attachments_item_id_knowledge_items",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_knowledge_attachments"),
    )
    op.create_index(
        "ix_knowledge_attachments_item",
        "knowledge_attachments",
        ["item_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_knowledge_attachments_item", table_name="knowledge_attachments")
    op.drop_table("knowledge_attachments")
    op.drop_index("ix_knowledge_relations_target", table_name="knowledge_relations")
    op.drop_table("knowledge_relations")
    op.drop_index("ix_knowledge_items_user_updated", table_name="knowledge_items")
    op.drop_table("knowledge_items")
