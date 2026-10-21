"""Cria a tabela country e carrega a lista do ISO 3166-1.

Revision ID: 0008
Revises: 0007
Create Date: 2026-10-21

"""
from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

from app.data.countries import load_country_rows

revision: str = "0008"
down_revision: str | None = "0007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

country_table = sa.table(
    "country",
    sa.column("iso2", sa.CHAR(2)),
    sa.column("iso3", sa.CHAR(3)),
    sa.column("numeric_code", sa.CHAR(3)),
    sa.column("name", sa.String(120)),
    sa.column("long_name", sa.String(200)),
    sa.column("native_name", sa.String(120)),
    sa.column("phone_code", sa.String(8)),
    sa.column("continent", sa.String(24)),
    sa.column("capital", sa.String(120)),
    sa.column("currency_code", sa.CHAR(3)),
    sa.column("currency_symbol", sa.String(8)),
    sa.column("tld", sa.String(12)),
    sa.column("flag_emoji", sa.String(8)),
)


def upgrade() -> None:
    op.create_table(
        "country",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("iso2", sa.CHAR(2), nullable=False),
        sa.Column("iso3", sa.CHAR(3), nullable=False),
        sa.Column("numeric_code", sa.CHAR(3), nullable=True),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("long_name", sa.String(length=200), nullable=True),
        sa.Column("native_name", sa.String(length=120), nullable=True),
        sa.Column("phone_code", sa.String(length=8), nullable=True),
        sa.Column("continent", sa.String(length=24), nullable=False),
        sa.Column("capital", sa.String(length=120), nullable=True),
        sa.Column("currency_code", sa.CHAR(3), nullable=True),
        sa.Column("currency_symbol", sa.String(length=8), nullable=True),
        sa.Column("tld", sa.String(length=12), nullable=True),
        sa.Column("flag_emoji", sa.String(length=8), nullable=False),
        sa.PrimaryKeyConstraint("id", name="pk_country"),
        sa.UniqueConstraint("iso2", name="uq_country_iso2"),
        sa.UniqueConstraint("iso3", name="uq_country_iso3"),
    )
    op.create_index("ix_country_name", "country", ["name"])
    op.create_index("ix_country_continent_name", "country", ["continent", "name"])
    op.bulk_insert(country_table, list(load_country_rows()))


def downgrade() -> None:
    op.drop_index("ix_country_continent_name", table_name="country")
    op.drop_index("ix_country_name", table_name="country")
    op.drop_table("country")
