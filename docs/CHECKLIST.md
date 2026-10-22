# Checklist de conformidade

Use antes de abrir PR em qualquer projeto do ecossistema.

## Backend

- [ ] configuração herda `AthenaSettings`; nenhum segredo no código;
- [ ] `.env.example` lista toda variável obrigatória;
- [ ] `create_app` herda handlers, CORS, `request_id`, `/health` e as rotas
      base (`/auth`, `/users`, `/secrets`);
- [ ] migrations versionadas, com as tabelas do núcleo e as do projeto;
- [ ] `Base` única compartilhada;
- [ ] toda tabela sensível tem coluna de nível (`SensitivityType`);
- [ ] áreas registradas em `areas.register(...)` no boot;
- [ ] toda leitura filtra `guard.visible(area)`;
- [ ] toda escrita passa por `ensure_create` / `ensure_write`;
- [ ] reclassificação nunca passa de `ensure_new_level`;
- [ ] registro acima do nível responde 404, não 403;
- [ ] toda resposta usa `api_response` com `code` estável;
- [ ] erro de negócio é `AppError`; validação é 422;
- [ ] listagem paginada no banco, com `meta` de paginação;
- [ ] decisão negada e escrita por secret vão para a auditoria;
- [ ] teste de regra, de permissão (área/nível/flag) e do bug corrigido;
- [ ] `uv run pytest` verde.

## Frontend

- [ ] app consome `atena_ui`; nenhum widget duplicado do package;
- [ ] tema vem de `AppTheme.light/dark(palette: ...)`;
- [ ] nenhuma cor, espaçamento ou duração fora dos tokens;
- [ ] `ToatHost` envolve o app; TOAT só para resultado de ação;
- [ ] erro que exige decisão usa `InlineMessage` ou o erro do campo;
- [ ] cliente HTTP lê o envelope e lança `ApiException` pelo `code`;
- [ ] `X-Client-Offset-Minutes` enviado; paginação lida de `meta`;
- [ ] lista cobre carregando, vazio, erro e sucesso (`StatusView`);
- [ ] ação destrutiva confirma nomeando o alvo;
- [ ] ação em andamento bloqueia duplo envio;
- [ ] todo texto visível está em strings (sem hardcode);
- [ ] recurso tem estados de carregamento e de erro;
- [ ] nenhuma feature importa outra;
- [ ] `flutter test` e `flutter analyze` verdes.

## Segurança

- [ ] JWT assinado com `SECRET_KEY` de 48+ bytes, fora do repositório;
- [ ] senha com Argon2; token de secret guardado como hash SHA-256;
- [ ] token de secret aparece uma única vez (na criação ou rotação);
- [ ] endpoint de credencial/usuário/configuração exige sessão;
- [ ] `CORS_ORIGINS` restrito em produção;
- [ ] rate limit nas rotas de login;
- [ ] auditoria de criação, rotação, revogação e uso de secret;
- [ ] dependência nova justificada e licença compatível.

## Documentação

- [ ] `AGENTS.md` do projeto reflete o que o código faz;
- [ ] README do projeto diz como rodar, testar e configurar;
- [ ] mudança de padrão foi feita no `atena-pattern`, não só no produto;
- [ ] widget/componente novo documentado no README do package.

## Entrega

- [ ] `docker compose config` sem erro e `.env.example` com toda variável obrigatória;
- [ ] `make up` sobe com banco novo e a migration roda no start;
- [ ] `.dockerignore` exclui `.env`, `.venv`, `build/`, `.dart_tool/` e testes;
- [ ] nenhuma credencial real no `.env` versionado (só exemplo com placeholder);
- [ ] `make test` verde.
