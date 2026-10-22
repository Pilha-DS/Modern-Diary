# Atalhos do dia a dia. O compose é o caminho oficial de execução do fork.
COMPOSE := docker compose

.PHONY: help env up down logs ps build migrate test test-backend test-frontend clean

help: ## Mostra os comandos
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk -F':.*?## ' '{printf "%-14s %s\n", $$1, $$2}'

env: ## Cria .env a partir do exemplo (não sobrescreve)
	@test -f .env || (cp .env.example .env && echo "criado .env — ajuste SECRET_KEY e senhas")

up: env ## Sobe banco, API e app
	$(COMPOSE) up -d --build

down: ## Para tudo (mantém o volume do banco)
	$(COMPOSE) down

logs: ## Acompanha os logs
	$(COMPOSE) logs -f

ps: ## Estado dos serviços
	$(COMPOSE) ps

build: ## Reconstrói as imagens
	$(COMPOSE) build

migrate: ## Aplica as migrations no container da API
	$(COMPOSE) exec api uv run alembic upgrade head

test: test-backend test-frontend ## Roda toda a suíte

test-backend: ## Núcleo + API (pytest)
	cd packages/atena_pattern && uv run python -m pytest
	cd application/backend && uv run python -m pytest

test-frontend: ## Package + app (flutter test)
	cd packages/atena_ui && flutter test
	cd application/frontend && flutter test

clean: ## Para tudo e apaga o volume do banco
	$(COMPOSE) down -v
