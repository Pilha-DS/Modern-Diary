# atena-pattern (backend)

Núcleo reutilizável das APIs do ecossistema. Entrega o que não é de domínio:

- envelope único de resposta e tratamento de erro (`responses`, `errors`, `app`);
- `request_id` e fuso do cliente (`middleware`, `request_context`);
- sessão JWT, senha com Argon2 e token de credencial (`security`);
- usuários, roles, credenciais (`api_secrets`) e auditoria de acesso;
- níveis de sensibilidade e o motor de permissões por área (`access`);
- paginação (`pagination`);
- rotas herdadas: `/auth`, `/users` e `/secrets`.

O domínio (notas, metas, agenda, etc.) fica no projeto, não aqui.

## Como o projeto usa

Este package mora em `packages/atena_pattern` e é consumido por
`application/backend` por caminho (`tool.uv.sources`), então mexer aqui reflete
no produto sem reinstalar.

1. Herde `AthenaSettings` e crie o app:

```python
from atena_pattern import AthenaSettings, create_app

class Settings(AthenaSettings):
    app_name: str = "Minha API"

app = create_app(Settings())
```

2. Defina as áreas do projeto e registre a coluna de sensibilidade de cada uma:

```python
from enum import StrEnum

from atena_pattern.core.access import areas

class Area(StrEnum):
    NOTE = "notas"
    GOAL = "metas"

areas.register(Area.NOTE.value, Note.sensitivity)
areas.register(Area.GOAL.value, Goal.sensitivity)
```

3. Use o guard em toda leitura e escrita de domínio:

```python
from atena_pattern import AccessGuard, Actor

guard = AccessGuard(session, actor)

rows = session.scalars(
    select(Note).where(Note.user_id == actor.user_id, *guard.visible(Area.NOTE.value))
).all()

guard.ensure_create(Area.NOTE.value, target_type="note")
guard.ensure_write(Area.NOTE.value, note.sensitivity, target_type="note", target_id=note.id)
```

4. Monte as migrations do projeto a partir de `atena_pattern.Base.metadata`.

## Testes

```bash
uv venv .venv
uv pip install -e ".[dev]"
uv run pytest
```

Os testes usam SQLite em memória e um modelo de amostra (`tests/sample.py`) para
exercitar o motor de permissões sem depender de domínio.
