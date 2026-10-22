# O padrão

Este documento explica a arquitetura que o `atena-pattern` entrega e por que ela
está separada do produto. As regras obrigatórias estão no `AGENTS.md`; aqui está
o desenho.

## Princípio

```text
o que é transversal  ->  packages/  (atena_pattern, atena_ui, docs)
o que é domínio      ->  application/ (backend, frontend)
o que é esqueleto    ->  também application/, já funcionando no fork
```

O `Modern-Diary` originou o padrão. Ele é a referência de uso real, mas não é a
fonte: depois da extração, o padrão evolui aqui e o produto é forkado daqui.

## Backend

### Camadas

```text
rota (FastAPI)      recebe, valida pela schema e responde pelo envelope
  |
schema (Pydantic)   contrato de entrada e saída
  |
serviço             regra de negócio; é o único que decide
  |
repositório         consulta e escrita no banco
  |
modelo (SQLAlchemy) tabela
```

Nada de SQL na rota, nada de regra no repositório. O serviço recebe sessão e
devolve dados; a rota monta a resposta.

### O que vem da biblioteca

```text
atena_pattern/
├── app.py              create_app(): handlers, CORS, /health, rotas herdadas
├── core/
│   ├── config.py       AthenaSettings (o projeto herda)
│   ├── database.py     Base, engine e get_db
│   ├── responses.py    envelope único
│   ├── errors.py       AppError / FieldError
│   ├── middleware.py   request_id e fuso do cliente
│   ├── security.py     JWT, Argon2, token de secret
│   └── access.py       Actor, AccessGuard e AreaRegistry
├── models/             User, Role, ApiSecret, permissões, auditoria
├── repositories/       user, api_secret, system_state
├── services/           auth, user, secret
├── routes/             /auth, /users, /secrets
└── schemas/            envelope, pagination, auth, user, secret, sensitivity
```

O projeto importa e, quando precisa, herda. Não copia.

### Permissões

O modelo tem três peças:

1. **Pessoa** — `User` + `Role` (ADMIN, MODERATOR, USER). A sessão JWT identifica
   o dono e enxerga tudo do próprio usuário.
2. **Credencial** — `ApiSecret`, com um token (`prefixo_...`) que só aparece uma
   vez; o banco guarda hash e pista visual. Cada credencial tem uma linha por
   **área**, com:
   - `read_level`: até qual nível ela lê;
   - `can_create`: se pode criar;
   - `can_write`: se pode alterar/excluir.
3. **Nível** — `Sensitivity`, hierárquico: `PUBLIC < BASIC < MODERATE <
   COMPLEX < SECRET`. `ALL` é só limite de credencial, nunca nível de registro.

O `AccessGuard` é o único ponto de decisão:

```python
visible(area)                  # critérios para filtrar a leitura no banco
optional_visible(area)         # None quando a credencial não tem a área
ensure_create(area, ...)       # exige can_create
ensure_write(area, level, ...) # exige can_write e nível dentro do lido
ensure_new_level(area, level)  # não deixa reclassificar acima do lido
```

O projeto registra as áreas e as colunas:

```python
areas.register(Area.NOTE.value, Note.sensitivity)
areas.register(Area.GOAL.value, Goal.sensitivity)
```

Por que o registro em vez de um dicionário na biblioteca: a biblioteca não pode
importar `Note`, `Goal` ou qualquer modelo de domínio. Sem essa inversão, o
"padrão" seria o Modern-Diary com outro nome.

Decisões de resposta:

- registro acima do nível de leitura → **404**, não 403, para não revelar que
  existe;
- área não configurada para a credencial → **403** `AREA_NOT_PERMITTED`;
- criação acima do nível lido é permitida, mas não dá leitura depois;
- toda decisão negada e toda escrita feita por secret vai para a auditoria.

### Envelope

Um formato, sempre:

```text
code, success, data, message, errors, meta, request_id, timestamp
```

Nenhum campo é omitido. O `code` é o contrato; o front decide pelo `code`, nunca
pelo texto. O `request_id` é gerado no middleware e volta no header; o fuso do
cliente é lido de `X-Client-Offset-Minutes`.

### Banco

- `Base` única, com convenção de nomes de constraint.
- Migrations versionadas no projeto; a biblioteca entrega `Base.metadata` para o
  Alembic importar.
- As tabelas do núcleo mantêm os nomes históricos (`users`, `api_secrets`,
  `secret_area_permissions`, `secret_audit_logs`, `system_state`).
- `system_state` guarda uma linha só e serializa o primeiro cadastro: o primeiro
  usuário vira ADMIN; os seguintes, USER.

## Frontend

### Um package

`atena_ui` é **um** package, não uma árvore (`core`, `design_system`, `network`).
Ele contém:

```text
theme/      tokens, paleta e tema (AppPalette, AppTheme, AppSemanticColors)
toat/       notificação padrão
widgets/    componentes reutilizáveis
sensitivity/ seletor de nível, quando o projeto tiver permissões
```

O que **não** entra no package:

- tela, rota, feature e idioma do projeto;
- HTTP e armazenamento;
- identidade fixa (a paleta vem por parâmetro);
- widget de domínio (um `ActivityTile` de agenda vira `ChecklistTile` genérico
  ou fica no app).

### Estrutura do app

```text
app/
├── lib/src/
│   ├── core/           config, network, strings, preferências
│   ├── features/       feature-first
│   │   └── <feature>/
│   │       ├── data/         repositório e DTO
│   │       ├── domain/       modelo e regra de apresentação
│   │       └── presentation/ controller, tela e widgets
│   └── app.dart        tema, TOAT e navegação raiz
└── test/               teste de widget e de controller
```

O app depende do package por `path` em desenvolvimento e por `git` (com tag) em
produção. O cliente HTTP do envelope fica no **app** (`application/frontend`), não
no package:
o package não faz rede.

### Tema

```dart
const myPalette = AppPalette.example; // troque com copyWith ou monte a sua

MaterialApp(
  theme: AppTheme.light(palette: myPalette),
  darkTheme: AppTheme.dark(palette: myPalette),
  themeMode: preferences.themeMode,
  builder: (context, child) => ToatHost(
    controller: toatController,
    child: child ?? const SizedBox.shrink(),
  ),
);
```

Sem `AppSemanticColors` registrado, os widgets que leem a extensão falham em
debug. O tema é a única fonte de cor, espaçamento e duração.

## Por que fork

| Alternativa | Problema |
| --- | --- |
| só a biblioteca publicada | o esqueleto (Alembic, cliente HTTP, features) continua sem ponto de partida e a versão precisa ser publicada a cada correção |
| só cópia de pastas | cada projeto diverge; correção de permissão vira trabalho manual em N lugares |
| gerador de projeto | gera uma vez e perde o vínculo; melhorar o padrão não alcança quem já gerou |

O fork mantém padrão, esqueleto e produto no mesmo repositório, com as três
responsabilidades separadas por pasta:

- `packages/` — transversal, consumido por caminho, não conhece o produto;
- `application/` — o produto, único lugar com domínio;
- `docs/` + `AGENTS.md` — a regra que vale para os dois.

Correção transversal é feita em `packages/` e vale na hora para o produto, sem
publicar versão. Melhoria que serve a outro projeto volta para a base; domínio
fica no fork.

## Limites conhecidos

- A biblioteca não gera migrations do projeto: ela expõe `Base.metadata`.
- O package não tem cliente HTTP: isso é do app.
- Nomes de tabela do núcleo estão congelados para não quebrar bancos existentes.
- `application/` é ponto de partida: uma vez que o domínio cresce, ele pertence
  ao fork e deixa de acompanhar a base automaticamente.
- A migração do Modern-Diary é uma etapa separada; até lá, a cópia dele não
  evolui.
