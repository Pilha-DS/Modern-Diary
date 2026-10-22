# Backend com o padrão

Como evoluir a API que já existe em `application/backend`. O exemplo cria uma
área `notes` com um modelo `Note`.

O esqueleto já vem pronto no fork: `create_app`, `Settings`, `areas`, Alembic,
`.env.example` e um teste. O trabalho aqui é acrescentar domínio.

## 1. Dependência

`application/backend/pyproject.toml` já aponta para o núcleo por caminho:

```toml
[tool.uv.sources]
atena-pattern = { path = "../../packages/atena_pattern", editable = true }
```

Não publique nem instale o padrão por git: editar `packages/atena_pattern`
reflete em `application/backend` na hora.

```bash
cd application/backend
uv venv && uv sync
```

## 2. Configuração

```python
# app/core/config.py
from atena_pattern import AthenaSettings


class Settings(AthenaSettings):
    app_name: str = "Atena App"
    # configurações só deste projeto
```

Variáveis de ambiente mínimas (`.env.example`):

```bash
APP_NAME=Atena App
ENVIRONMENT=development
DATABASE_URL=mysql+pymysql://user:senha@localhost:3306/minha_api
# python -c "import secrets; print(secrets.token_urlsafe(48))"
SECRET_KEY=troque-esta-chave-por-uma-aleatoria-de-48-bytes
ACCESS_TOKEN_EXPIRE_MINUTES=60
CORS_ORIGINS=*
```

## 3. Áreas e sensibilidade

Toda tabela que pode ser lida por credencial precisa de uma coluna de nível.
Registre a área uma única vez, na inicialização do app:

```python
# app/core/areas.py
from enum import StrEnum

from atena_pattern.core.access import areas
from app.models.note import Note


class Area(StrEnum):
    NOTE = "notes"


def register_areas() -> None:
    areas.register(Area.NOTE.value, Note.sensitivity)
```

Área nova = registro novo. O motor de permissões não muda.

## 4. Modelo e migration

```python
# app/models/note.py
from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from atena_pattern import Base, Sensitivity
from atena_pattern.models.sensitivity import SensitivityType


class Note(Base):
    __tablename__ = "notes"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), nullable=False)
    title: Mapped[str] = mapped_column(String(120), nullable=False)
    sensitivity: Mapped[Sensitivity] = mapped_column(
        SensitivityType(), nullable=False, default=Sensitivity.PUBLIC
    )
```

O Alembic do projeto importa os modelos do núcleo e os do projeto:

```python
# alembic/env.py
from atena_pattern import Base
from atena_pattern import models  # registra as tabelas do núcleo
from app import models  # registra as tabelas do projeto

target_metadata = Base.metadata
```

A migration inicial cria `users`, `system_state`, `api_secrets`,
`secret_area_permissions`, `secret_audit_logs` e as tabelas do projeto. Depois
disso, toda alteração é uma migration nova.

## 5. Camadas

Schema:

```python
# app/schemas/note.py
from pydantic import BaseModel, ConfigDict
from atena_pattern.schemas.sensitivity import DataLevel


class NoteCreate(BaseModel):
    title: str
    sensitivity: DataLevel = "publico"


class NoteResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    sensitivity: str
```

Repositório:

```python
# app/repositories/note_repository.py
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.note import Note


class NoteRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_page(self, user_id: int, criteria: list, offset: int, limit: int):
        where = [Note.user_id == user_id, *criteria]
        total = self.session.scalar(select(func.count(Note.id)).where(*where)) or 0
        rows = self.session.scalars(
            select(Note).where(*where).order_by(Note.id).offset(offset).limit(limit)
        ).all()
        return list(rows), total
```

Serviço:

```python
# app/services/note_service.py
from atena_pattern import AccessGuard, Actor, AppError

from app.models.note import Note
from app.repositories.note_repository import NoteRepository


class NoteService:
    def __init__(self, session, actor: Actor) -> None:
        self.session = session
        self.actor = actor
        self.guard = AccessGuard(session, actor)
        self.notes = NoteRepository(session)

    def list_page(self, offset: int, limit: int):
        criteria = self.guard.visible("notes")
        return self.notes.list_page(self.actor.user_id, criteria, offset, limit)

    def create(self, title: str, sensitivity) -> Note:
        self.guard.ensure_create("notes", target_type="note")
        note = Note(
            user_id=self.actor.user_id,
            title=title,
            sensitivity=sensitivity,
        )
        self.session.add(note)
        self.session.commit()
        self.guard.record_created("notes", "note", note.id)
        self.session.commit()
        return note

    def update(self, note_id: int, title: str) -> Note:
        note = self.session.get(Note, note_id)
        if note is None or note.user_id != self.actor.user_id:
            raise AppError(code="NOTE_NOT_FOUND", message="Nota não encontrada.", status_code=404)
        self.guard.ensure_write(
            "notes", note.sensitivity, target_type="note", target_id=note.id
        )
        note.title = title
        self.session.commit()
        return note
```

Leitura de um registro usa o mesmo critério da lista:

```python
criteria = self.guard.visible("notes")
note = self.session.scalar(
    select(Note).where(Note.id == note_id, Note.user_id == self.actor.user_id, *criteria)
)
if note is None:
    raise AppError(code="NOTE_NOT_FOUND", message="Nota não encontrada.", status_code=404)
```

Rota:

```python
# app/api/routes/notes.py
from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session

from atena_pattern import Actor, get_db
from atena_pattern.api.deps import get_actor
from atena_pattern.core.responses import api_response
from atena_pattern.schemas.pagination import PageParams, pagination_meta

from app.schemas.note import NoteCreate, NoteResponse
from app.services.note_service import NoteService

router = APIRouter(prefix="/notes", tags=["notes"])


@router.get("")
def list_notes(
    request: Request,
    page: PageParams = Depends(),
    session: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
):
    notes, total = NoteService(session, actor).list_page(page.offset, page.per_page)
    return api_response(
        request,
        code="NOTES_LISTED",
        data=[NoteResponse.model_validate(note).model_dump(mode="json") for note in notes],
        meta=pagination_meta(page.page, page.per_page, total),
    )
```

`get_actor` aceita sessão (JWT) ou credencial (token com o prefixo da
configuração). Endpoint que administra credencial, usuário ou configuração usa
`get_current_user`, que exige sessão.

## 6. Montar o app

```python
# app/main.py
from atena_pattern import create_app

from app.core.areas import register_areas
from app.core.config import Settings
from app.api.routes.notes import router as notes_router

register_areas()

app = create_app(
    Settings(),
    routers=[notes_router],
    title="Atena App",
)
```

`create_app` já entrega `/api/v1/auth`, `/api/v1/users`, `/api/v1/secrets`,
`/health`, envelope, CORS, `request_id` e o tratamento de erro.

## 7. Testes

Use SQLite em memória, uma configuração de teste e a mesma sessão nos testes:

```python
# tests/conftest.py
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.pool import StaticPool

from atena_pattern import AthenaSettings, SystemState, configure, configure_database
from atena_pattern import Base, create_app, get_db
from app.core.areas import register_areas
from app.main import app

settings = AthenaSettings(
    environment="test",
    database_url="sqlite://",
    secret_key="test-secret-key-with-at-least-32-characters",
)
configure(settings)
engine, TestingSessionFactory = configure_database(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
register_areas()
app = create_app(settings)
```

Regra de negócio tem teste; bug corrigido ganha o teste que reproduz o bug.
Teste de permissão cobre os três eixos: área, nível e flag (`create`/`write`).

## Checklist rápido

- [ ] configuração herda `AthenaSettings`, sem segredo no código;
- [ ] áreas registradas no boot;
- [ ] toda tabela sensível tem coluna de nível;
- [ ] toda leitura filtra `guard.visible(area)`;
- [ ] toda escrita passa por `ensure_create`/`ensure_write`;
- [ ] listagem paginada no banco com `meta`;
- [ ] erro pelo `AppError` e envelope único;
- [ ] migration versionada;
- [ ] teste de regra e de permissão.
