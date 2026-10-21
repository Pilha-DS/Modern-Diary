"""Separa as notas do dia em agenda_notes e migra a nota única existente.

Revision ID: 0010
Revises: 0009
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import mysql

revision: str = "0010"
down_revision: str | None = "0009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "agenda_notes",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("day", sa.Date(), nullable=False),
        sa.Column(
            "content",
            sa.Text().with_variant(mysql.LONGTEXT(), "mysql"),
            nullable=False,
        ),
        sa.Column("sensitivity", sa.Integer(), server_default=sa.text("1"), nullable=False),
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
            name="fk_agenda_notes_user_id_users",
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint("id", name="pk_agenda_notes"),
    )
    op.create_index("ix_agenda_notes_user_day", "agenda_notes", ["user_id", "day"])
    op.create_index(
        "ix_agenda_notes_user_sensitivity",
        "agenda_notes",
        ["user_id", "sensitivity"],
    )

    op.execute(
        sa.text(
            "INSERT INTO agenda_notes "
            "(user_id, day, content, sensitivity, created_at, updated_at) "
            "SELECT user_id, day, note, sensitivity, created_at, updated_at "
            "FROM agenda_days "
            "WHERE note IS NOT NULL AND LENGTH(TRIM(note)) > 0"
        )
    )
    op.drop_column("agenda_days", "note")


def downgrade() -> None:
    op.add_column("agenda_days", sa.Column("note", sa.Text(), nullable=True))
    op.execute(
        sa.text(
            "UPDATE agenda_days AS day "
            "JOIN agenda_notes AS note ON note.id = ("
            "  SELECT MIN(first_note.id) FROM agenda_notes AS first_note "
            "  WHERE first_note.user_id = day.user_id AND first_note.day = day.day"
            ") SET day.note = note.content"
        )
    )
    op.drop_index("ix_agenda_notes_user_sensitivity", table_name="agenda_notes")
    op.drop_index("ix_agenda_notes_user_day", table_name="agenda_notes")
    op.drop_table("agenda_notes")
