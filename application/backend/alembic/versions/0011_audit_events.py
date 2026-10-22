"""Cria a auditoria de ações do usuário (histórico e grafo do dia).

Revision ID: 0011
Revises: 0010
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0011"
down_revision: str | None = "0010"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "audit_events",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column(
            "occurred_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "area",
            sa.Enum(
                "KNOWLEDGE",
                "GOAL",
                "NOTE",
                "DAY",
                "ACTIVITY",
                "TAG",
                name="audit_area",
            ),
            nullable=False,
        ),
        sa.Column(
            "kind",
            sa.Enum(
                "CREATE",
                "UPDATE",
                "DELETE",
                "LINK",
                "UNLINK",
                name="audit_event_kind",
            ),
            nullable=False,
        ),
        sa.Column("source_type", sa.String(length=20), nullable=False),
        sa.Column("source_ref", sa.String(length=40), nullable=False),
        sa.Column("source_label", sa.String(length=160), nullable=False),
        sa.Column("target_type", sa.String(length=20), nullable=True),
        sa.Column("target_ref", sa.String(length=40), nullable=True),
        sa.Column("target_label", sa.String(length=160), nullable=True),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_audit_events_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_audit_events"),
    )
    op.create_index(
        "ix_audit_events_user_day_occurred",
        "audit_events",
        ["user_id", "day", "occurred_at"],
    )
    op.create_index(
        "ix_audit_events_user_occurred",
        "audit_events",
        ["user_id", "occurred_at"],
    )


def downgrade() -> None:
    op.drop_table("audit_events")
