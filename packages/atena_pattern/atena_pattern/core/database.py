from collections.abc import Iterator
from typing import Any

from sqlalchemy import Engine, MetaData, create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

NAMING_CONVENTION = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


class Base(DeclarativeBase):
    """Base declarativa única. Todo modelo do núcleo e do projeto usa esta."""

    metadata = MetaData(naming_convention=NAMING_CONVENTION)


_engine: Engine | None = None
_session_factory: sessionmaker | None = None


def configure_database(url: str, **engine_kwargs: Any) -> tuple[Engine, sessionmaker]:
    """Cria o engine e a fábrica de sessões que o núcleo vai usar.

    Em teste com SQLite em memória, passe `connect_args={"check_same_thread":
    False}` e `poolclass=StaticPool`.
    """
    global _engine, _session_factory
    _engine = create_engine(
        url,
        pool_pre_ping=True,
        pool_recycle=3600,
        **engine_kwargs,
    )
    _session_factory = sessionmaker(
        bind=_engine,
        autoflush=False,
        expire_on_commit=False,
    )
    return _engine, _session_factory


def database_is_configured() -> bool:
    return _session_factory is not None


def get_engine() -> Engine:
    if _engine is None:
        raise RuntimeError("Banco não configurado: chame configure_database(url).")
    return _engine


def get_session_factory() -> sessionmaker:
    if _session_factory is None:
        raise RuntimeError("Banco não configurado: chame configure_database(url).")
    return _session_factory


def get_db() -> Iterator[Session]:
    session = get_session_factory()()
    try:
        yield session
    finally:
        session.close()


def reset_database() -> None:
    """Descarta engine e fábrica. Uso em teste."""
    global _engine, _session_factory
    _engine = None
    _session_factory = None
