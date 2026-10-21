"""Cria as credenciais de integração e o nível de sensibilidade dos dados.

Revision ID: 0006
Revises: 0005
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0006"
down_revision: str | None = "0005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SENSITIVITY_PUBLIC = 1
AREA_VALUES = ("KNOWLEDGE", "GOAL", "DAY", "ACTIVITY")
DATA_TABLES = ("knowledge_items", "goals", "agenda_days", "agenda_activities")


def _sensitivity_column() -> sa.Column:
    return sa.Column(
        "sensitivity",
        sa.Integer(),
        nullable=False,
        server_default=sa.text(str(SENSITIVITY_PUBLIC)),
    )


def upgrade() -> None:
    for table in DATA_TABLES:
        op.add_column(table, _sensitivity_column())
        op.create_index(
            f"ix_{table}_user_sensitivity",
            table,
            ["user_id", "sensitivity"],
        )

    op.create_table(
        "api_secrets",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(length=60), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("token_hint", sa.String(length=12), nullable=False),
        sa.Column("revoked_at", sa.DateTime(), nullable=True),
        sa.Column("last_used_at", sa.DateTime(), nullable=True),
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
            name="fk_api_secrets_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_api_secrets"),
        sa.UniqueConstraint("user_id", "name", name="uq_api_secrets_user_name"),
        sa.UniqueConstraint("token_hash", name="uq_api_secrets_token_hash"),
    )
    op.create_index(
        "ix_api_secrets_user_created",
        "api_secrets",
        ["user_id", "created_at"],
    )

    op.create_table(
        "secret_area_permissions",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("secret_id", sa.Integer(), nullable=False),
        sa.Column("area", sa.Enum(*AREA_VALUES, name="secret_area"), nullable=False),
        sa.Column(
            "read_level",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "can_create",
            sa.Boolean(),
            server_default=sa.text("0"),
            nullable=False,
        ),
        sa.Column(
            "can_write",
            sa.Boolean(),
            server_default=sa.text("0"),
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
            ["secret_id"],
            ["api_secrets.id"],
            name="fk_secret_area_permissions_secret_id_api_secrets",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_secret_area_permissions"),
        sa.UniqueConstraint(
            "secret_id",
            "area",
            name="uq_secret_area_permissions_area",
        ),
    )

    op.create_table(
        "secret_audit_logs",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("secret_id", sa.Integer(), nullable=False),
        sa.Column("area", sa.Enum(*AREA_VALUES, name="secret_area"), nullable=False),
        sa.Column(
            "action",
            sa.Enum("READ", "CREATE", "UPDATE", "DELETE", name="secret_audit_action"),
            nullable=False,
        ),
        sa.Column(
            "result",
            sa.Enum("ALLOWED", "DENIED", name="secret_audit_result"),
            nullable=False,
        ),
        sa.Column("target_type", sa.String(length=40), nullable=True),
        sa.Column("target_id", sa.Integer(), nullable=True),
        sa.Column("request_id", sa.String(length=64), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_secret_audit_logs_user_id_users",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["secret_id"],
            ["api_secrets.id"],
            name="fk_secret_audit_logs_secret_id_api_secrets",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_secret_audit_logs"),
    )
    op.create_index(
        "ix_secret_audit_logs_secret_created",
        "secret_audit_logs",
        ["secret_id", "created_at"],
    )
    op.create_index(
        "ix_secret_audit_logs_user_created",
        "secret_audit_logs",
        ["user_id", "created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_secret_audit_logs_user_created",
        table_name="secret_audit_logs",
    )
    op.drop_index(
        "ix_secret_audit_logs_secret_created",
        table_name="secret_audit_logs",
    )
    op.drop_table("secret_audit_logs")
    op.drop_table("secret_area_permissions")
    op.drop_index("ix_api_secrets_user_created", table_name="api_secrets")
    op.drop_table("api_secrets")

    for table in DATA_TABLES:
        op.drop_index(f"ix_{table}_user_sensitivity", table_name=table)
        op.drop_column(table, "sensitivity")
