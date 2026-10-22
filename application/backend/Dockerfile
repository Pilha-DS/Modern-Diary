# Build a partir da raiz do repositório (docker compose já faz):
#   docker build -f application/backend/Dockerfile .
FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /src

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1

# Só os manifests primeiro: o cache da camada sobrevive a mudança de código.
COPY packages/atena_pattern/pyproject.toml packages/atena_pattern/README.md /src/packages/atena_pattern/
COPY application/backend/pyproject.toml application/backend/uv.lock /src/application/backend/

WORKDIR /src/application/backend
RUN uv sync --frozen --no-dev --no-install-project

COPY packages/atena_pattern /src/packages/atena_pattern
COPY application/backend /src/application/backend
RUN uv sync --frozen --no-dev

EXPOSE 8000

# A migration roda antes de subir: container novo nunca atende com banco atrasado.
CMD ["sh", "-c", "uv run alembic upgrade head && uv run uvicorn app.main:app --host 0.0.0.0 --port 8000 --no-access-log"]
