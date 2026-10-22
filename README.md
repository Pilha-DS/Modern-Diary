# Modern-Diary

Sistema para ajudar no dia a dia: agenda, notas e ferramentas de estudo e de controle de coisas diárias.

**Back** — Python com FastAPI. Separação lógica por usuário, SQLAlchemy para persistência e Alembic para versionamento do banco. Os endpoints ficam documentados em `<endereço>/docs`.

**Front** — Flutter, para suporte a várias plataformas.

**Conexões** — Front em `http://localhost:8080`, API em `http://localhost:8000` e MySQL em `localhost:3306`.

> Status: base pronta — backend com cadastro, login JWT, roles, migrations e envelope único; front Flutter com agenda completa (notas do dia em markdown, atividades por dia e visão anual de calendário), notas em markdown com editor e prévia, metas com etapas e progresso, conhecimentos com conexões em rede e metas ligadas, tags compartilhadas entre conhecimentos, metas e dias, sessão e lista de usuários do ADMIN.

## Agenda

A agenda é um conjunto de dias, onde é possível colocar notas, atividades e marcações, além de acompanhar o que foi planejado e o que foi concluído.

- **Início (dashboard)**: mês atual em destaque com sombra azul, ocupando 40% da linha, ao lado da seleção rápida das telas (Calendário, Notas, Metas, Conhecimentos, Live graph, Tags, Credenciais e Usuários para ADMIN). As notas e as atividades do dia são editadas no dia, no calendário. Passar o mouse sobre um dia abre um mini-modal ao lado dele com o feriado, o nível e as tags do dia, a prévia das notas e a lista de atividades — sem abrir o dia.
- **Calendário**: visão do ano inteiro. O mês atual ganha sombra azul, cada mês cresce ao passar o mouse e o clique em um dia abre o dia em um modal, sem sair da visão anual. O dia atual fica marcado em verde, o dia aberto fica azul sólido e cada marca (nota, atividade, prioridade alta e feriado) tem cor própria, para nunca se confundir com a seleção. Feriado é um status do dia, em laranja, exibido no calendário e no painel do dia; não é nota nem atividade. Cada dia tocável ganha apoio visual em cinza-claro no hover. O dia abre em leitura: o botão **Editar** libera criar nota, atividade, tag e trocar níveis; **Concluir** volta para a leitura. O dia aceita várias notas ao mesmo tempo.
- **Dia (modal)**: a ordem é sempre data e dia da semana, nível do dia e tags, notas e atividades. As notas aparecem recolhidas em cartões com a primeira linha e a contagem de palavras; o clique (ou o hover) revela o conteúdo renderizado. No modo de edição, cada cartão ganha os botões de editar e excluir: editar abre o `MarkdownEditor` já no texto puro, com o nível de sensibilidade da nota no mesmo formulário.
- **Metas**: lista em três colunas, doze por página. Cada meta tem título, descrição e prazo opcionais, etapas opcionais, barra de progresso com a contagem `x/y`, e ações de concluir, reabrir, arquivar, desarquivar, editar e excluir.
- **Navegação**: a bola central abre o menu orbital com as abas (Início, Pesquisar, Calendário, Notas, Metas, Conhecimentos, Live graph, Tags, Credenciais, Usuários para ADMIN, Ajustes e Sair). O item Início fica no centro do arco. Os itens são só ícones, agrupados sem nome; ao ficar 2s sobre um deles aparece o nome no tooltip. Cada item usa a superfície invertida do tema (claro no escuro, escuro no claro) para destacar o menu, e o item da aba atual fica na cor da identidade. O logo no header leva de volta para Início. A **Pesquisa universal** também abre pelo ícone no header e pela tecla `Q`.
- **Header e rodapé**: o header tem a identidade do app, o ícone da pesquisa universal e o avatar do usuário; o avatar abre um menu escondido com as configurações básicas (tema, foto, nacionalidade, localidade e telefone), também acessíveis em **Ajustes** no menu orbital. A nacionalidade é escolhida na tabela `countries` por um modal com busca por nome, sigla ou código ISO e carregamento sob demanda. Em **Ajustes**, o botão **Puxar feriados** baixa os feriados do ano (país da nacionalidade) e os guarda no banco; sem nacionalidade, ele pede que o usuário escolha uma antes. O rodapé mostra quem fez o projeto, o contato e a versão, configurados em build (`APP_AUTHOR_NAME`, `APP_CONTACT_EMAIL`, `APP_AUTHOR_PHONE`, `APP_AUTHOR_SITE`, `APP_VERSION`) — vazios usam o padrão em `application/frontend/app/lib/src/core/config/app_info.dart`. Toda tela tem a altura mínima da área visível, então o rodapé só aparece depois de rolar.
- **Cartões**: listas de notas, conhecimentos, metas e credenciais usam o mesmo grid (`AppCardGrid`): colunas calculadas pela largura e **cartões da mesma linha com a mesma altura**.

## Notas

Bloco de anotações em markdown, separado das notas do dia: serve para texto livre, ideias e
rascunhos que não pertencem a uma data.

- **Lista**: cartões no mesmo grid responsivo do projeto, com título (opcional, mostra
  "Sem título"), prévia do markdown, selo de sensibilidade, data de atualização e botão de
  fixar. As fixadas ficam no topo; doze por página com "carregar mais".
- **Busca e filtro**: a busca tem debounce e roda no back (`q`), junto do filtro
  `Todas`/`Fixadas`. Ordenação por fixadas e atualização, desempatada pelo `id`.
- **Editor**: título opcional e conteúdo em markdown. O texto aparece renderizado;
  clicar em cima dele mostra o markdown puro para editar e, ao sair, volta a renderizar.
  A barra de formatação (título, negrito, itálico, lista, checklist, citação, código e
  link) altera o texto no cursor e o rodapé mostra contagem de caracteres e palavras.
  O mesmo campo é usado nas notas do dia, no conhecimento e no detalhe dele; nas notas do
  dia ele só aparece no modo de edição do dia.
- **Ações**: criar, editar, fixar/desafixar e excluir. Excluir pede confirmação nomeando a
  nota; toda ação desabilita enquanto executa e responde pelo TOAT.
- **Sensibilidade**: cada nota tem nível próprio (`publico` a `sigiloso`) e respeita o
  mesmo limite de leitura de secrets da área `notas`.
- **Limite**: até 5.000 notas por conta; acima disso a API responde `NOTE_LIMIT`.

## Conhecimentos

Base de conhecimento pessoal com conexões entre as ideias — quanto mais links entre os
conhecimentos, mais densa fica a rede.

- **Lista (padrão)**: cartões com título, prévia do conteúdo em markdown, links externos,
  anexos e as conexões com outros conhecimentos, doze por página com "carregar mais".
- **Grafo**: a mesma base vista como rede neural. Cada conhecimento é um nó — o tamanho
  cresce com o número de conexões — e cada conexão é uma linha. Tocar em um nó abre o
  conhecimento e, a partir dele, os demais nós conectados. Ao passar o mouse sobre um nó,
  abre um mini-modal ao lado dele com o nível, as tags e a contagem de conexões; os dados
  vêm da própria rede, então o hover não faz requisição. O painel fica à direita do nó e
  vira para a esquerda (ou para cima/baixo) quando não há espaço.
- **Grafo interativo**: arrastar um nó muda e fixa a posição dele; arrastar o fundo
  desloca a rede e a roda do mouse dá zoom. O painel **Ajustes da rede** controla a
  repulsão entre os nós, a distância das conexões e a gravidade que puxa a rede para o
  centro — mexer em um ajuste refaz a simulação sem perder o lugar dos nós. No modo
  **Conectar nós**, arrastar um nó até outro cria a conexão direto no grafo; os demais
  arrastos voltam a mover. **Reorganizar** solta os nós fixados e refaz o layout, e
  **Centralizar** volta o zoom e o deslocamento ao original. Hover e seleção destacam a
  vizinhança e apagam o resto da rede. **Tela cheia** abre a rede ocupando toda a janela,
  com os mesmos ajustes e o mesmo desenho, e o mesmo botão volta para a versão encaixada.
- **Conhecimento**: título, conteúdo em markdown, links externos com nome opcional e
  anexos de até 5 MB cada (até dez por conhecimento), guardados no banco e baixados por
  link temporário. O conteúdo aparece renderizado; clicar nele mostra o markdown puro
  para editar e o texto novo é salvo ao sair.
- **Conexões**: dois conhecimentos se conectam nos dois sentidos. Excluir um conhecimento
  desfaz as conexões e remove os anexos dele.
- **Metas ligadas**: um conhecimento pode ser ligado a metas ativas e mostrar essa lista
  no cartão e no detalhe, com opção de desligar.

## Grafo de vida (Live graph)

Tudo o que o usuário registrou em um só desenho: dias, atividades, notas, metas e
conhecimentos. Cada registro é um nó e cada ligação é uma linha.

- **Conexões automáticas**: dois conhecimentos conectados, um conhecimento ligado a uma
  meta e uma atividade do dia já aparecem ligados, sem nenhum passo extra.
- **Conexões manuais**: no modo **Conectar nós**, arrastar um nó até outro liga os dois
  registros, de qualquer tipo. Só essas ligações aparecem em **Conexões**, onde podem ser
  desfeitas; as automáticas são desfeitas na origem (a relação, a meta ou o dia).
- **Filtro**: as etiquetas mostram todos os registros ou só um tipo, e o filtro vai para o
  back (o grafo não filtra uma lista já carregada).
- **Abrir o registro**: o clique no nó leva à área de origem — conhecimento, meta, nota
  ou o dia da atividade e do dia.
- **Desenho**: arrastar move e fixa o nó, o fundo desloca, a roda dá zoom, **Ajustes da
  rede** controla repulsão, distância e gravidade, e **Tela cheia** abre a rede inteira.
  Tocar em um nó mostra o tipo e as conexões antes de abrir.
- **Escopo**: até 80 registros por tipo, os mais recentes; os registros ligados à mão
  entram mesmo fora dessa janela. `meta.truncated` avisa quando o teto foi atingido.
- **Acesso**: cada tipo respeita a área e o nível de sensibilidade de quem lê; um registro
  escondido não aparece no grafo nem pode ser ligado. Excluir um registro desfaz as
  ligações dele.

## Pesquisa universal

Um campo único para procurar em tudo: notas, conhecimentos, metas, notas do dia e
atividades. O índice vive no banco (FULLTEXT), não na tela.

- **Como abrir**: o ícone de pesquisa no header, o item **Pesquisar** no menu orbital ou a
  tecla **Q**. Com o cursor em qualquer campo de texto, `Q` é texto e não abre a pesquisa.
- **Filtros**: tipo (mais de um ao mesmo tempo), período (`from`/`to`), tag (só
  conhecimentos e metas, que são os registros que recebem tag) e nível de sensibilidade.
  Os filtros vão para o back; o front nunca filtra a página já recebida.
- **Resultado**: o cartão mostra o tipo, a data, o nível (quando não é público), o título
  e a prévia do markdown — no dia, a prévia é o conteúdo da nota. Tocar fecha o modal e
  abre o registro na área de origem; nota do dia e atividade abrem o dia.
- **Paginação**: 20 por página com **Carregar mais**, lendo `meta` do envelope.
- **Acesso**: cada tipo respeita a área e o nível de leitura de quem pesquisou; uma
  credencial sem a área simplesmente não recebe aquele tipo. Registro acima do nível é
  omitido, nunca sinalizado.
- **Limite**: no MySQL, o FULLTEXT ignora termos com menos de 3 caracteres; buscas curtas
  voltam vazias.

## Tags

Tags organizam conhecimentos, metas e dias do mês com uma relação N:M.

- **Menu de tags**: cadastro, edição e exclusão de tags com nome, cor e descrição. Cada
  tag mostra quantos usos tem; ao abrir, lista onde está sendo usada (conhecimento, meta
  ou dia), paginado. Os cartões ficam estreitos e altos no mesmo grid dos conhecimentos:
  até quatro por linha, com o total de usos preso no rodapé do cartão.
- **Uso**: nos formulários de conhecimento e de meta e no dia do calendário, o seletor de
  tags busca pelo nome e permite criar uma tag nova direto no modal, já marcando-a no
  registro.
- **Filtros**: as listas de conhecimentos e de metas aceitam `tag_id` na API e têm uma
  barra de filtro por tag no front; o grafo de conhecimentos usa o mesmo filtro. A busca e
  a paginação continuam no back.

## Estrutura Logica

A estrutura lógica não define a estrutura de pastas final, somente a estrutura para a construção da lógica do software.

```js
MD - Raiz
  application/ - Frontend e Backend
    backend/ - Regras de negócio, modelos, persistência e o que o usuário não pode alterar
      app/ - Código fonte
    frontend/ - Parte visual, onde o usuário tem acesso irrestrito
      app/ - Código fonte (web)
        src/ - Lógica do front
        Package/ - Pacotes reutilizáveis
  docs/ - Todos os documentos
    structure/ - Documentos estruturais
    PLAN. - Indica o que será feito (a IA deve desconsiderar este arquivo)
  AGENTS. - Regras de desenvolvimento do software
  README. - Sobre o projeto, como rodar e etc.
```

## Backend

```text
application/backend/
  app/
    api/          - Rotas e dependências HTTP (auth, users, secrets, agenda, metas, conhecimentos, tags, notas, países e feriados)
    core/         - Configuração, banco, segurança, erros e envelope
    data/         - Catálogos e fontes externas lidas pelo back (países e feriados)
    models/       - Tabelas SQLAlchemy
    repositories/ - Acesso ao banco
    schemas/      - Entrada e saída validada por Pydantic
    services/     - Regras de negócio
  alembic/        - Migrations versionadas
  tests/          - Testes de regra de negócio e de API
```

### Como rodar com Docker (recomendado)

Na raiz do projeto:

```bash
cp application/backend/.env.example application/backend/.env
docker compose up -d --build
```

O `docker-compose.yml` da raiz inclui o do backend, então o comando funciona tanto na raiz
quanto em `application/backend`. Sobe três serviços:

| Serviço | Endereço padrão | O que é |
| --- | --- | --- |
| `web` | `http://localhost:8080` | Flutter web servido pelo nginx |
| `api` | `http://localhost:8000` | FastAPI (veja `/docs`) |
| `db` | `localhost:3306` | MySQL 8.4 |

O `web` encaminha `/api` para o serviço `api`, então o navegador fala com a mesma origem:
não há CORS nem necessidade de informar a URL da API no build. O primeiro build do `web`
baixa o SDK do Flutter e demora alguns minutos; os seguintes usam o cache das camadas.

O `api` espera o MySQL ficar saudável e roda `alembic upgrade head` antes de subir o
servidor.

Se a porta `8000`, `3306` ou `8080` já estiver em uso, defina `API_PORT`, `MYSQL_PORT`
(no `application/backend/.env`) e `FRONTEND_PORT` (variável de ambiente ou arquivo `.env`
na raiz). Acesse então o front na porta escolhida. Use `docker compose down` para parar e
`docker compose down -v` para apagar também o volume do MySQL.

Para apontar o front para uma API em outro endereço (fora do compose), informe no build:

```bash
API_PUBLIC_URL=https://api.exemplo.com docker compose build web
```

### Como rodar local (sem Docker)

Requisitos: Python 3.12+, [uv](https://docs.astral.sh/uv/) e MySQL 8.

```bash
cd application/backend
cp .env.example .env        # ajuste DATABASE_URL se necessário
uv sync
uv run alembic upgrade head
uv run uvicorn app.main:app --reload --no-access-log
```

O banco `modern_diary` precisa existir. Se o MySQL estiver no Docker, `docker compose up -d db` cria o banco com o usuário do `.env`.

### Variáveis de ambiente

| Variável | Para que serve |
| --- | --- |
| `DATABASE_URL` | Conexão SQLAlchemy (`mysql+pymysql://usuario:senha@host:3306/modern_diary`) |
| `SECRET_KEY` | Assinatura dos tokens JWT (mínimo 32 caracteres) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Validade do token, em minutos |
| `CORS_ORIGINS` | Origens liberadas para o Flutter web, separadas por vírgula (`*` só em dev) |
| `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD` | Usadas pelo `docker compose` para criar o MySQL |
| `API_PORT`, `MYSQL_PORT` | Portas publicadas no host pelo `docker compose` (padrão `8000` e `3306`) |
| `FRONTEND_PORT` | Porta do front no `docker compose` (padrão `8080`) |
| `API_PUBLIC_URL` | URL da API compilada no front quando ela não é a do próprio compose (padrão vazio, usando `/api` pelo nginx) |

### Roles

- `ADMIN` — existe **uma única** conta, criada no primeiro cadastro do sistema. Gerencia os usuários.
- `MODERATOR` — usuário promovido pelo ADMIN. Ainda sem permissões próprias (base para as ferramentas de moderação).
- `USER` — role padrão de todo cadastro depois do primeiro.

O primeiro cadastro é decidido dentro de uma transação com lock na tabela `system_state`: cadastros simultâneos não criam dois admins. O ADMIN é imutável — não pode ser atribuído a outra conta nem rebaixado.

> Atenção: enquanto o primeiro cadastro não existir, qualquer pessoa que cadastrar vira ADMIN. Em produção, crie a conta ADMIN antes de expor a API publicamente.

### Secrets e níveis de sensibilidade

Cada conta pode criar credenciais (`secrets`) para integrações externas usarem a API em
nome dela. O token aparece uma única vez, na criação e na rotação; o banco guarda apenas o
hash SHA-256 e o final do token, para o usuário reconhecer a credencial. Só a sessão do
dono cria, consulta, altera e revoga secrets — uma secret nunca administra credenciais,
usuários ou tags.

O token da secret usa o mesmo header da sessão: `Authorization: Bearer mds_...`. O
prefixo `mds_` separa a credencial do JWT de sessão.

Toda informação (conhecimento, meta, dia, atividade e nota) tem um nível de sensibilidade:

| Nível | Valor | Uso |
| --- | --- | --- |
| Público | `publico` | menor sensibilidade |
| Básico | `basico` | |
| Moderado | `moderado` | |
| Complexo | `complexo` | |
| Sigiloso | `sigiloso` | maior sensibilidade |
| Todos | `all` | apenas como limite de leitura de uma secret |

O nível vai no corpo dos endpoints (`sensitivity`) e volta nas respostas. Registros criados
sem o campo ficam `publico`; os dados que já existiam receberam `publico` na migration
`0006` e podem ser reclassificados com `PATCH`.

Cada secret tem permissões independentes por área — `conhecimentos`, `metas`, `dias`,
`atividades` e `notas`:

```json
{
  "name": "integracao_externa",
  "permissions": {
    "conhecimentos": { "read": "complexo", "create": true, "write": true },
    "metas": { "read": "basico", "create": false, "write": false }
  }
}
```

As regras são aplicadas no backend, em um único ponto (`app/core/access.py`):

- **Leitura**: só o nível autorizado e os anteriores. Registro acima do limite não aparece
  em lista alguma (o `meta.total` também respeita o limite) e responde 404 na consulta
  individual, para não revelar que existe.
- **Criação**: independe do nível de leitura. A secret pode criar em qualquer nível,
  inclusive acima do que lê, mas isso não dá acesso ao registro depois.
- **Escrita**: exige `write` habilitado **e** o registro dentro do nível de leitura.
  Alterar o nível de um registro só é permitido até o limite da credencial.
- **Área não configurada** significa sem acesso (`403`). Nada é liberado por padrão.
- **Revogar** (`DELETE`) e **rotacionar** (`POST .../rotate`) invalidam o token na hora.
- **Auditoria**: cada criação, alteração, exclusão e recusa feita por uma secret fica em
  `GET /api/v1/secrets/{id}/audit`, com área, ação, resultado, alvo e `request_id`. Leituras
  bem-sucedidas não entram no log (evita uma linha por consulta); o `last_used_at` da
  secret é atualizado.

### Endpoints

| Método | Rota | Acesso | O que faz |
| --- | --- | --- | --- |
| `GET` | `/health` | Público | Verifica se a API está no ar |
| `POST` | `/api/v1/auth/register` | Público | Cadastra; o primeiro vira ADMIN e devolve token |
| `POST` | `/api/v1/auth/login` | Público | Autentica e devolve token |
| `GET` | `/api/v1/auth/me` | Autenticado | Devolve o próprio usuário |
| `GET` | `/api/v1/users` | ADMIN | Lista paginada de usuários (`page`, `per_page`; teto de 100) |
| `PATCH` | `/api/v1/users/{id}/role` | ADMIN | Troca a role entre `MODERATOR` e `USER` |
| `GET` | `/api/v1/secrets` | Sessão | Lista as credenciais paginadas (sem o token) |
| `POST` | `/api/v1/secrets` | Sessão | Cria a credencial e devolve o token uma única vez |
| `GET` | `/api/v1/secrets/{id}` | Sessão | Detalha a credencial e as permissões por área |
| `PATCH` | `/api/v1/secrets/{id}` | Sessão | Renomeia e/ou substitui as permissões |
| `POST` | `/api/v1/secrets/{id}/rotate` | Sessão | Troca o token e invalida o anterior |
| `DELETE` | `/api/v1/secrets/{id}` | Sessão | Revoga a credencial e invalida o token |
| `GET` | `/api/v1/secrets/{id}/audit` | Sessão | Lista as decisões de acesso da credencial |
| `GET` | `/api/v1/goals` | Autenticado | Lista metas paginadas (`status=ACTIVE\|COMPLETED\|ARCHIVED`, `page`, `per_page`, `tag_id`) |
| `GET` | `/api/v1/goals/{id}` | Autenticado | Detalha uma meta com etapas, progresso e tags |
| `POST` | `/api/v1/goals` | Autenticado | Cria meta, com etapas opcionais |
| `PATCH` | `/api/v1/goals/{id}` | Autenticado | Edita, conclui/reabre e arquiva/desarquiva a meta |
| `DELETE` | `/api/v1/goals/{id}` | Autenticado | Exclui a meta e suas etapas |
| `POST` | `/api/v1/goals/{id}/steps` | Autenticado | Adiciona uma etapa |
| `PATCH` | `/api/v1/goals/{id}/steps/{step_id}` | Autenticado | Marca ou desmarca uma etapa |
| `DELETE` | `/api/v1/goals/{id}/steps/{step_id}` | Autenticado | Exclui uma etapa |
| `GET` | `/api/v1/knowledge` | Autenticado | Lista conhecimentos paginados (`page`, `per_page`, `tag_id`; teto de 100) |
| `GET` | `/api/v1/knowledge/graph` | Autenticado | Nós e conexões da rede (`tag_id`; até 300 nós; `meta.truncated` avisa) |
| `GET` | `/api/v1/knowledge/{id}` | Autenticado | Detalhe com links, conexões e anexos |
| `POST` | `/api/v1/knowledge` | Autenticado | Cria conhecimento com links externos |
| `PATCH` | `/api/v1/knowledge/{id}` | Autenticado | Edita título, conteúdo e links |
| `DELETE` | `/api/v1/knowledge/{id}` | Autenticado | Exclui sabendo que conexões e anexos vão junto |
| `POST` | `/api/v1/knowledge/{id}/relations` | Autenticado | Conecta a outro conhecimento (`target_id`) |
| `DELETE` | `/api/v1/knowledge/{id}/relations/{target_id}` | Autenticado | Desfaz a conexão |
| `POST` | `/api/v1/knowledge/{id}/attachments` | Autenticado | Envia anexo (`multipart/form-data`, campo `file`, até 5 MB) |
| `DELETE` | `/api/v1/knowledge/{id}/attachments/{attachment_id}` | Autenticado | Remove o anexo |
| `GET` | `/api/v1/knowledge/{id}/attachments/{attachment_id}/download?token=...` | Token temporário do próprio anexo | Abre ou baixa o anexo; o token dura 10 minutos e não expõe o token de sessão |
| `GET` | `/api/v1/tags` | Autenticado | Lista tags paginadas com `usage_count` (`q`, `page`, `per_page`) |
| `POST` | `/api/v1/tags` | Autenticado | Cria tag com nome único, cor e descrição |
| `PATCH` | `/api/v1/tags/{id}` | Autenticado | Edita nome, cor e descrição |
| `DELETE` | `/api/v1/tags/{id}` | Autenticado | Exclui a tag e desfaz todas as ligações |
| `GET` | `/api/v1/tags/{id}/usages` | Autenticado | Lista onde a tag é usada: conhecimentos, metas e dias |
| `GET` | `/api/v1/notes` | Autenticado | Lista notas paginadas (`q`, `pinned`, `page`, `per_page`; teto de 100) |
| `POST` | `/api/v1/notes` | Autenticado | Cria uma nota em markdown |
| `GET` | `/api/v1/notes/{id}` | Autenticado | Detalha a nota com o conteúdo completo |
| `PATCH` | `/api/v1/notes/{id}` | Autenticado | Edita título/conteúdo, fixa/desafixa e troca a sensibilidade |
| `DELETE` | `/api/v1/notes/{id}` | Autenticado | Exclui a nota |
| `GET` | `/api/v1/agenda/summary` | Autenticado | Resume os dias com registro no período (`from`, `to`) |
| `GET` | `/api/v1/agenda/days/{day}` | Autenticado | Detalha o dia: nível, notas, atividades, tags e feriado |
| `PUT` | `/api/v1/agenda/days/{day}/sensitivity` | Autenticado | Define o nível do dia |
| `PUT` | `/api/v1/agenda/days/{day}/tags` | Autenticado | Define as tags do dia |
| `POST` | `/api/v1/agenda/days/{day}/notes` | Autenticado | Cria uma nota no dia (várias por dia) |
| `PATCH` | `/api/v1/agenda/notes/{note_id}` | Autenticado | Edita o conteúdo ou o nível da nota |
| `DELETE` | `/api/v1/agenda/notes/{note_id}` | Autenticado | Exclui a nota do dia |
| `POST` | `/api/v1/agenda/days/{day}/activities` | Autenticado | Cria uma atividade no dia |
| `PATCH` | `/api/v1/agenda/activities/{activity_id}` | Autenticado | Edita, conclui e troca o nível da atividade |
| `DELETE` | `/api/v1/agenda/activities/{activity_id}` | Autenticado | Exclui a atividade |
| `GET` | `/api/v1/life/graph` | Autenticado | Grafo de vida com nós e arestas (`types` separados por vírgula; até 80 nós por tipo; `meta.truncated` avisa) |
| `GET` | `/api/v1/search` | Autenticado | Pesquisa universal no título e no markdown (`q`, `types`, `from`, `to`, `tag_id`, `sensitivity`, `page`, `per_page`; teto de 100) |
| `POST` | `/api/v1/life/links` | Autenticado | Liga dois registros de qualquer tipo (`source_type`, `source_ref`, `target_type`, `target_ref`) |
| `DELETE` | `/api/v1/life/links` | Autenticado | Desfaz a ligação manual entre os dois registros |
| `GET` | `/api/v1/countries` | Autenticado | Lista os países da tabela de referência (`q`, `continent`, `page`, `per_page`; teto de 100) |
| `POST` | `/api/v1/holidays/sync` | Autenticado | Puxa os feriados do país (`country_iso2`) e guarda o ano corrente e o seguinte |

#### Países (`country`)

Catálogo fixo do ISO 3166-1, usado para a nacionalidade nos Ajustes. Não há criação,
edição nem exclusão pela API: a lista vive em
`application/backend/app/data/countries.json`, e a migration `0008` cria a tabela `country`
e insere as 249 linhas ao aplicá-la.

| Coluna | Exemplo | Observação |
| --- | --- | --- |
| `iso2` | `BR` | código de duas letras; único |
| `iso3` | `BRA` | código de três letras; único |
| `numeric_code` | `076` | código numérico da ONU |
| `name` | `Brasil` | nome curto em português |
| `long_name` | `República Federativa do Brasil` | nome oficial em português |
| `native_name` | `Brasil` | nome na grafia local |
| `phone_code` | `+55` | DDI; vazio em países sem telefonia (ex.: Antártida) |
| `continent` | `América do Sul` | continente ou região em português |
| `capital` | `Brasília` | capital |
| `currency_code` / `currency_symbol` | `BRL` / `R$` | moeda |
| `tld` | `.br` | domínio de topo |
| `flag_emoji` | `🇧🇷` | bandeira pronta para exibir |

A busca (`q`) olha nome, nome oficial, grafia nativa e código ISO. A nacionalidade
escolhida fica nos ajustes deste dispositivo (`AppPreferences`), junto de tema, foto,
localidade e telefone; nada vai para a API.

#### Feriados (`holiday`)

Feriado é um **status do dia** no calendário, não nota nem atividade. A fonte externa é a
[Nager.Date](https://date.nager.at/), gratuita e sem chave, que entrega o ano inteiro de um
país em uma chamada. O back consulta a fonte só quando o botão **Puxar feriados** é
acionado nos Ajustes e grava o resultado na tabela `holiday`: a agenda passa a ler do
banco, sem consultar a internet de novo.

- Países habilitados por enquanto: `BR` e `SE` (`application/backend/app/data/holidays.py`).
  Outro país responde `HOLIDAY_COUNTRY_NOT_ENABLED`.
- O botão usa a nacionalidade dos Ajustes; sem nacionalidade, o app pede que o usuário
  escolha uma antes de chamar a API.
- A sincronização cobre o ano corrente e o seguinte e substitui os feriados anteriores do
  usuário (a nacionalidade é uma só). Se a fonte falhar, o banco fica como estava.
- Só feriados globais entram no calendário; feriado regional não é do país inteiro.
- `GET /api/v1/agenda/summary` e `GET /api/v1/agenda/days/{day}` trazem `holiday` com o
  nome do feriado (ou `null`). O calendário mostra o dia em laranja e o painel exibe o
  status **Feriado**.

| Coluna | Exemplo | Observação |
| --- | --- | --- |
| `user_id` | `1` | dono do feriado; a consulta sempre filtra por ele |
| `country_iso2` | `BR` | país da nacionalidade que gerou a sincronização |
| `day` | `2026-01-01` | data do feriado |
| `name` | `New Year's Day` | nome na fonte |
| `local_name` | `Confraternização Universal` | nome no idioma local, exibido na tela |


Autenticação: envie `Authorization: Bearer <access_token>` (sessão) ou
`Authorization: Bearer mds_...` (token de uma secret). O token de sessão expira em
`ACCESS_TOKEN_EXPIRE_MINUTES`; o da secret vale até ser revogado ou rotacionado. Não há
refresh token nesta etapa.

### Envelope único

Toda resposta segue o mesmo formato, inclusive erro e lista vazia: `code`, `success`, `data`, `message`, `errors`, `meta`, `request_id`, `timestamp`. O front decide o comportamento pelo `code`, nunca pelo texto de `message`. O `request_id` volta no corpo e no header `X-Request-ID` para correlacionar com o log.

### Migrations

```bash
uv run alembic revision --autogenerate -m "descricao"
uv run alembic upgrade head
uv run alembic downgrade -1
```

Nunca altere uma migration já aplicada: crie outra.

### Testes

```bash
cd application/backend
uv run pytest
```

Os testes usam SQLite em memória e cobrem o cadastro inicial, login, envelope, paginação, permissões por role, o ciclo de vida das metas (etapas, progresso, conclusão e arquivo), os conhecimentos (links, conexões, grafo, anexos e isolamento por usuário), as notas (CRUD, fixar, busca, paginação e isolamento), o grafo de vida (ligações entre tipos, filtro, exclusão em cascata e isolamento por usuário) e o acesso por secret (níveis, permissões independentes por área, criação acima do nível lido, revogação, rotação e auditoria).

## Frontend

```text
application/frontend/
  app/                          - Aplicativo Flutter (web, linux, android)
    lib/
      src/
        core/                   - Configuração, cliente HTTP, strings e sessão
        features/
          auth/                 - Login, cadastro, sessão e usuário
          goals/                - Metas com etapas, progresso e arquivo
          home/                 - Tela inicial
          knowledge/            - Conhecimentos, links, anexos e rede em grafo
          notes/                - Notas em markdown, com editor, prévia e busca
          users/                - Lista paginada de usuários do ADMIN
    test/                       - Testes de widget e do cliente HTTP
  packages/
    modern_diary_ui/            - Tema, tokens, componentes e TOAT reutilizáveis
```

O app não decide regra de negócio: cadastro, roles e paginação vêm da API. O token é
enviado em `Authorization: Bearer` e guardado em `shared_preferences`; ao abrir, o app
restaura a sessão chamando `/api/v1/auth/me`.

### Como rodar

Com Docker, o front sobe junto com a API (veja "Como rodar com Docker"). Para rodar local:

Requisitos: Flutter 3.27+ e a API no ar. Se `flutter` não for encontrado, adicione o SDK
ao PATH (`export PATH="$HOME/development/flutter/bin:$PATH"`) ou reabra o terminal. No
Arch, defina também `CHROME_EXECUTABLE=/usr/bin/google-chrome-stable` para o
`flutter run -d chrome` enxergar o navegador.

```bash
cd application/frontend/app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Para gerar o build web:

```bash
flutter build web --dart-define=API_BASE_URL=http://localhost:8000
```

O `API_BASE_URL` padrão é `http://localhost:8000`. Se você trocou `API_PORT` no backend,
use a mesma porta aqui (ex.: `http://localhost:8001`). Em dispositivo físico, use o IP da
máquina e libere essa origem em `CORS_ORIGINS` no backend.

O `Dockerfile` fica em `application/frontend` e compila o web com
`--dart-define=API_BASE_URL` vazio: a chamada sai como `/api/...` e o nginx do container
encaminha para o serviço `api`. Por isso a imagem funciona em qualquer porta e sem CORS.
O build do Flutter é feito uma vez e servido como arquivo estático em produção.

### Testes

```bash
cd application/frontend/app
flutter analyze
flutter test

cd ../packages/modern_diary_ui
flutter analyze
flutter test
```

Os exemplos de uso dos componentes do package estão em
[`application/frontend/packages/modern_diary_ui/README.md`](application/frontend/packages/modern_diary_ui/README.md).

## Credenciais de teste

Não há usuário pré-criado: o primeiro cadastro é o ADMIN. Para testar localmente:

1. `POST /api/v1/auth/register` com `{"username": "admin", "password": "admin1234"}` → vira `ADMIN`.
2. `POST /api/v1/auth/register` com `{"username": "user", "password": "user1234"}` → vira `USER`.
3. Faça login com `admin` / `admin1234` para acessar `/api/v1/users` e trocar a role de `user`.
