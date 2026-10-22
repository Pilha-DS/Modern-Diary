# AGENTS.md

Regras base do padrão Atena. Todo projeto do ecossistema lê este arquivo antes de
construir software. O projeto pode acrescentar regras próprias, mas não pode
contrariar as daqui.

```text
documentação: português
identificadores (código, variáveis, arquivos): inglês
```

Em caso de conflito entre documentos, a ordem é: este arquivo, a decisão
explícita do usuário para o caso, a documentação do projeto e, por último, o
código existente. Divergência não é resolvida em silêncio: ela é mostrada com as
opções antes de agir.

---

# Regras Front

## Gerais

Os padrões são obrigatórios. Alguns existem para melhorar o desenvolvimento.

- 1. Evite bordas visíveis. Prefira fundos sólidos, que eliminam a necessidade de bordas.
- 2. Nunca escreva cor, tamanho ou espaçamento fixo no widget: use os tokens do tema. Se o token não existir, crie-o no lugar certo em vez de escrever o valor na tela.
- 3. Todo widget novo nasce no package. Se algo parecido já existe, use o existente em vez de duplicar.
- 4. A tela se adapta ao espaço disponível: nada de largura/altura fixa que quebre em tela pequena.
- 5. Todo componente prevê os quatro estados: carregando, vazio, erro e sucesso. Tela sem estado de erro e de vazio é tela incompleta.
- 6. Toda ação dispara um feedback (carregando → resultado) e não pode ser executada duas vezes enquanto está em andamento.
- 7. Texto visível fica no arquivo de strings/idioma, nunca solto no widget.
- 8. Acessibilidade mínima é obrigatória: contraste legível, alvo de toque confortável e rótulo semântico em ícones e botões.
- 9. Lista consome endpoint paginado: carrega a primeira página e busca as próximas sob demanda (scroll infinito ou "carregar mais"). Nunca peça "todos os registros" nem carregue tudo antes de exibir.
- 10. O front não calcula página, total nem offset: lê `meta` (ou `next_cursor`/`has_more`) da resposta e para quando não há mais.
- 11. Busca, filtro e ordenação vão para o back por query param, com debounce na digitação. Não filtre em memória uma lista que já veio paginada.
- 12. Contador, totalizador e resumo no topo vêm do back no `meta` — nunca de `data.length`, que é só a página atual.
- 13. Markdown aparece sempre renderizado e é editado no editor do package, nunca em um campo cru.

## Ações

Regras para qualquer ação que o usuário executa (botão, menu, gesto).

- 1. Ação destrutiva ou irreversível (excluir conta, apagar histórico, apagar memória) exige confirmação explícita, nomeando o que será apagado, com a cor de erro.
- 2. Ação de risco moderado (excluir item, descartar edição) pede confirmação leve ou desfazer, com a cor de aviso.
- 3. Enquanto executa, a ação fica desabilitada com indicador de progresso: nunca permita duplo clique nem duplo envio.
- 4. Toda ação termina em um dos três estados: sucesso (confirmação), falha (mensagem clara) ou cancelada (nada muda).
- 5. Mensagem de erro diz o que aconteceu e o que o usuário pode fazer. Nunca apenas "erro", nunca stack trace.
- 6. Prefira desfazer a confirmar: se a ação é reversível com facilidade, ofereça "desfazer" em vez de bloquear com modal.
- 7. O botão de cancelar nunca fica mais chamativo que o de confirmar.
- 8. Se a ação falhar, a tela não pode ficar em estado inconsistente (nada de item sumido, contador errado ou loading travado).

Qualquer notificação — sucesso, aviso ou erro — é exibida no **TOAT**: a mensagem padrão do ecossistema, no canto superior direito.

- 9. Toda notificação sai pelo TOAT: mesma posição (direita superior), mesmo formato e mesmo componente. Não crie toast, banner, snackbar ou alerta paralelo na tela.
- 10. O TOAT tem variantes fixas — sucesso, aviso, erro e informação — e a cor de cada uma segue a seção Cores.
- 11. O TOAT traz sempre: ícone da variante, mensagem curta e, opcionalmente, uma ação ("desfazer", "ver detalhes"). Sem título longo, sem parágrafo.
- 12. Sucesso e informação fecham sozinhos (4 a 6 s). Aviso e erro só fecham por ação do usuário quando exigem decisão.
- 13. Erro que exige decisão não é TOAT: usa confirmação ou mensagem no próprio formulário, no campo que falhou. TOAT é para aviso passageiro.
- 14. No máximo 3 TOATs na tela, um por vez na mesma posição; o mais antigo sai primeiro. O TOAT nunca cobre header, botão principal nem conteúdo essencial.
- 15. O texto do TOAT diz o que aconteceu e o que fazer, em uma linha. Nunca exibe código de erro cru, stack trace ou nome de tabela — detalhe técnico só em "ver detalhes".
- 16. O TOAT é um componente único do package, criado uma vez e reutilizado. Chamada duplicada da mesma mensagem em sequência é agrupada, não empilhada.

## Cores

Cada projeto define a própria identidade na paleta (`AppPalette`), mas os papéis
semânticos são do ecossistema e não mudam.

- 1. O projeto deve ser elegante: evite cores sólidas e prefira sombras suaves. Evite sombras muito fortes e use cores sólidas apenas em casos muito específicos.
- 2. A cor de erro (vermelha) é usada somente para ações temerárias ou erros.
- 3. A cor de aviso (amarela) é usada somente para avisos (excluir item, descartar edição, mensagens leves).
- 4. A cor de identidade (`brand`) expressa a marca: logo, fundo e detalhes de identidade. Não use em qualquer lugar.
- 5. A cor neutra escura é a mais comum (fundo, header, área comum da logo).
- 6. A cor neutra clara é o padrão para botões sem efeito (cancelar ação, texto).
- 7. A cor de ação comum (azul) é o padrão para aceitar ações não temerárias.
- 8. Cores diferentes das anteriores podem ser usadas quando fizer sentido, mas devem ser evitadas.
- 9. A paleta não é escrita no widget: o widget lê `ColorScheme` e `AppSemanticColors` do tema.

## Navegação

Toda referência a outro registro é link, não texto solto.

- 1. Registro citado aparece clicável onde for citado; o mesmo vale para cada uso listado dentro de outro registro.
- 2. Quem troca de área é a tela raiz, por um único objeto de navegação. A área de origem só dispara o pedido e não conhece a navegação das outras.
- 3. O destino abre o registro pelo parâmetro de foco e devolve o pedido consumido, para não reabrir a cada rebuild.
- 4. Modal fecha antes de navegar.
- 5. Referência sem destino não é link: o chip fica sem ação, sem chevron e sem promessa visual.

## Package

O projeto usa o package `atena_ui` para simplificar a reutilização de código. O
uso do package é obrigatório.

- 1. Antes de criar qualquer widget, verifique se ele já existe no package; se existir, reutilize-o.
- 2. Se o padrão não existir no package e for necessário, crie-o dentro do package para que possa ser reutilizado por outros projetos.
- 3. O package não conhece a aplicação: não importe tela, rota, idioma ou regra de negócio de dentro dele.
- 4. Componente do package não faz HTTP nem acessa armazenamento: recebe dado por parâmetro e devolve evento por callback.
- 5. Widget que depende da identidade recebe a paleta, o ícone ou o texto por parâmetro. Nada de marca fixa.
- 6. Todo componente público do package tem um exemplo de uso documentado.
- 7. Um package, não uma árvore de packages: o que é visual e reutilizável mora em `atena_ui`.

# Regras Backend

## Geral

- 1. Mantenha pastas e arquivos bem separados e organizados: crie um arquivo para cada responsabilidade, ou use um que já faça aquilo. Separe as pastas em categorias para evitar muitos arquivos no mesmo local.
- 2. Não pode haver arquivos monolíticos, com milhares de linhas: separe em módulos (mas não crie um arquivo por função/método).
- 3. Cada camada tem uma responsabilidade: rota recebe, valida e responde; serviço aplica regra de negócio; repositório fala com o banco. Nada de SQL na rota nem regra no repositório.
- 4. Toda entrada da API é validada por schema antes de chegar na regra de negócio. Nunca confie no que o front mandou.
- 5. Toda alteração de banco é uma migration versionada: não altere o banco na mão nem edite migration já aplicada.
- 6. Toda consulta é filtrada pelo usuário autenticado. O identificador do usuário vem da sessão/token, nunca do corpo da requisição.
- 7. Segredos vêm de variável de ambiente, nunca do código. A exceção são as credenciais de teste, que seguem a regra geral.
- 8. Erro segue um formato único de resposta e não vaza detalhe interno (stack trace, SQL, nome de tabela).
- 9. Regra de negócio tem teste. Bug corrigido ganha um teste que reproduz o bug.
- 10. Operação demorada (IA, e-mail, importação) roda em background e devolve um estado para o front acompanhar; não bloqueie a requisição.
- 11. Log não carrega dado sensível: nada de senha, token, conteúdo privado ou dado pessoal.

O que é transversal (envelope, erro, sessão, credenciais, níveis, permissões) vem
da biblioteca `atena-pattern`. O projeto não copia esses módulos.

## Acesso por credencial (secrets)

O dono da conta usa a sessão (JWT) e enxerga tudo o que é dele. Integrações usam
uma secret, com permissões independentes por área. A decisão de acesso fica em um
único lugar (`atena_pattern.core.access`: `Actor` + `AccessGuard`); serviço nenhum
inventa a própria regra.

- 1. O projeto registra as próprias áreas e a coluna de sensibilidade de cada uma (`areas.register(Area.X.value, Model.sensitivity)`). O motor não conhece domínio.
- 2. Toda leitura filtra o nível de sensibilidade no banco (`guard.visible(area)`): lista, detalhe, grafo, contagem e `meta.total` usam o mesmo critério. Registro acima do nível responde 404, nunca 403, para não revelar que existe.
- 3. Área sem permissão configurada responde `AREA_NOT_PERMITTED`. Nada é liberado por padrão.
- 4. Criação depende só de `create`, em qualquer nível. Criar não dá leitura nem escrita depois: as próximas requisições continuam sujeitas ao nível de leitura.
- 5. Escrita e exclusão exigem `write` **e** o registro dentro do nível lido. O nível de um registro só pode ser alterado até o limite de leitura da credencial.
- 6. Dado ligado (título de conexão, resumo de outro registro) também é filtrado pela área e nível de quem lê. Um registro escondido não vaza por dentro de outro.
- 7. Toda decisão negada e toda criação/alteração/exclusão feita por secret vai para a auditoria (`secret_audit_logs`) com área, ação, resultado, alvo e `request_id`.
- 8. Área nova: registre a área, a coluna de sensibilidade e o filtro no serviço. O motor de permissões não muda.
- 9. Endpoint que gerencia secrets, usuários ou credenciais exige sessão. Secret nunca administra credencial, role nem configuração.
- 10. O token da secret nunca é gravado em texto: só o hash SHA-256 e o final, que serve de pista visual. O texto puro aparece apenas na criação e na rotação.

## Dados de referência (catálogos)

Catálogo fixo não é cadastro do usuário: ninguém cria, edita ou apaga catálogo
pela API.

- 1. A fonte única é um arquivo versionado no repositório. A migration cria a tabela e insere a lista lida desse arquivo; os testes usam o mesmo arquivo.
- 2. Nada de digitar o nome do item: o usuário escolhe uma linha da tabela. Deduzir a partir de texto livre gera duplicata e grafia divergente.
- 3. Listagem de referência segue a paginação padrão (`page`/`per_page`, teto do servidor) e aceita busca pelo nome e pelos códigos estáveis.
- 4. Novo dado de referência segue este caminho: arquivo em `app/data`, modelo só com leitura, `GET` paginado, sem POST/PATCH/DELETE.

## Fonte externa

Quando o dado vem de fora (calendário, cotação, catálogo público), a fonte externa
não é consultada ao abrir a tela.

- 1. A fonte só é chamada pela sincronização (`POST .../sync`), disparada por uma ação explícita. O resultado é gravado na tabela local.
- 2. A sincronização substitui os dados anteriores do usuário e só troca o banco depois de buscar tudo: falha da fonte não deixa estado pela metade e responde com `code` próprio.
- 3. A leitura é sempre filtrada pelo usuário autenticado.
- 4. A cor e o rótulo do dado externo vêm do tema e do idioma do projeto, nunca escritos no widget.
- 5. Habilitar uma fonte nova é acrescentar o registro na configuração do projeto; o motor de permissões e as telas não mudam.

## Envelope

Todo retorno da API — sucesso, erro, validação ou lista — usa o **mesmo envelope**.
A forma da resposta nunca muda; só os valores mudam.

- 12. Envelope obrigatório, com estes campos e nesta ordem: `code`, `success`, `data`, `message`, `errors`, `meta`, `request_id`, `timestamp`.
- 13. Nenhum campo é omitido. Quando não se aplica: `data` = `null`, `message` = `null`, `errors` = `[]`, `meta` = `{}`. O front nunca precisa adivinhar se a chave existe.
- 14. `code` é o contrato: string estável em `SCREAMING_SNAKE_CASE`. O front decide o que fazer pelo `code`, nunca pelo texto de `message`.
- 15. `success` é booleano e sempre coerente com o status HTTP e com `code`.
- 16. `data` é só o payload (objeto, lista ou `null`). Nunca carrega mensagem de status nem `success` duplicado.
- 17. `message` é texto para humano, curto e opcional. `errors` é a lista de falhas por campo, no formato `{ field, code, message }`.
- 18. `meta` carrega paginação e contadores: `page`, `per_page`, `total`, `total_pages` no modo offset, ou `next_cursor` e `has_more` no modo cursor. Lista vazia é `data: []` com `meta.total: 0` — não é erro.
- 19. `request_id` identifica a requisição para correlacionar com o log; `timestamp` é ISO 8601 em UTC, com `Z`.
- 20. O status HTTP continua correto e coerente com `code` (400, 401, 403, 404, 409, 422, 500). O envelope complementa o status, não o substitui.
- 21. O envelope vem da biblioteca (`atena_pattern.core.responses` e `create_app`). Não crie um segundo formato no projeto.

Sucesso:

```json
{
  "code": "RECURSO_CRIADO",
  "success": true,
  "data": { "id": "uuid", "title": "Exemplo" },
  "message": "Recurso criado com sucesso.",
  "errors": [],
  "meta": {},
  "request_id": "req_01H...",
  "timestamp": "2026-10-19T22:59:00Z"
}
```

Erro:

```json
{
  "code": "VALIDATION_ERROR",
  "success": false,
  "data": null,
  "message": "Não foi possível salvar.",
  "errors": [
    { "field": "title", "code": "REQUIRED", "message": "Campo obrigatório." }
  ],
  "meta": {},
  "request_id": "req_01H...",
  "timestamp": "2026-10-19T22:59:00Z"
}
```

Lista (mesma forma, inclusive quando vazia):

```json
{
  "code": "RECURSOS_LISTADOS",
  "success": true,
  "data": [],
  "message": null,
  "errors": [],
  "meta": { "page": 1, "per_page": 20, "total": 0, "total_pages": 0 },
  "request_id": "req_01H...",
  "timestamp": "2026-10-19T22:59:00Z"
}
```

## Paginação

Regra de ouro: quem controla a paginação é o **back**. O front pede; o back decide
quanto, como e até quando entregar.

- 22. Nenhum endpoint de listagem devolve a tabela inteira. Toda listagem é paginada, sem exceção, mesmo que hoje a tabela tenha 3 linhas.
- 23. `page` e `per_page` são validados por schema, sempre positivos. O servidor define o padrão (ex.: 20) e o teto (ex.: 100); pedido acima do teto é cortado no teto, não é erro.
- 24. O `offset` é calculado no servidor. Nunca aceite `offset`, `skip` ou `limit` crus do cliente sem validar contra o teto.
- 25. A paginação acontece no banco (`LIMIT`/`OFFSET` ou `WHERE` + cursor). Nunca traga tudo para a aplicação e corte depois; nada de `SELECT *` de tabela inteira em produção.
- 26. Lista grande, ou que muda enquanto é lida (histórico, feed, notificações), usa paginação por cursor (`cursor` + `limit`), não offset, para não duplicar nem pular item.
- 27. O `meta` informa a paginação: `page`, `per_page`, `total`, `total_pages` no modo offset; `next_cursor` e `has_more` no modo cursor. O front nunca deduz isso sozinho.
- 28. Ordenação é sempre determinística: toda consulta ordena por uma coluna e desempata pela chave primária. Sem ordem estável, a paginação repete ou perde registro.
- 29. `SELECT` só das colunas usadas na resposta. Relação 1:N não é carregada item por item dentro de laço (N+1): use join, eager loading ou consulta em lote.
- 30. Toda coluna usada em filtro, ordenação ou junção tem índice. Busca textual usa índice apropriado; `LIKE '%termo%'` sobre tabela grande é proibido.
- 31. `COUNT` caro não roda a cada página: nesse caso `meta` traz `has_more` (ou total aproximado) em vez de `total` exato, sem mudar a forma do envelope.
- 32. Agregação, relatório, exportação e IA não rodam na requisição síncrona: vão para background e o front acompanha por um endpoint de estado. Resultado grande também é paginado ou entregue como arquivo.
- 33. Importação e operação em massa entram em lotes com transação por lote, com limite de tamanho validado no servidor — nunca um insert/update gigante nem um payload sem teto.
- 34. Rota cara (IA, busca, exportação, sincronização) tem limite de frequência por usuário e devolve `code` próprio quando excede, sem derrubar a fila.
- 35. Consulta lenta é logada com duração e `request_id` para achar o gargalo. Timeout do servidor e tamanho máximo de corpo/upload são explícitos, não infinitos.

# Regras Gerais

As regras gerais normalmente são as mais importantes. São obrigatórias.

- 1. Nunca coloque regra de negócio dentro do front. Podem vir a ocorrer pontos de ataque.
- 2. Sempre coloque as credenciais de teste no final para o usuário poder testar.
- 3. Faça o menos possível para fazer o que foi pedido: somente o necessário para funcionar.
- 4. Mantenha o código o mais simples possível para fazer o que precisa ser feito.
- 5. Nome de variável, função e arquivo diz o que aquilo é: sem abreviação obscura e sem `data`, `aux` ou `temp`.
- 6. Não instale dependência sem necessidade: se resolve com o que já existe, resolva com o que já existe.
- 7. Não deixe código morto, comentado ou `TODO` sem dono: remova ou registre a tarefa.
- 8. Todo fluxo funciona do zero: se exige um passo manual não documentado, não está pronto.
- 9. Ao corrigir, conserte a causa e não o sintoma: se o mesmo bug pode reaparecer por outro caminho, feche o caminho.
- 10. Um padrão por assunto. Se o padrão já existe (envelope, TOAT, erro, estado de tela, nome de pasta), use o existente e siga exatamente a forma dele.
- 11. O padrão criado vale para casos futuros, não só para o atual: nasce reutilizável (na biblioteca, no package ou em módulo comum), não copiado de tela em tela.
- 12. O que é transversal vai para `atena-pattern`; o que é domínio fica no projeto. Na dúvida, pergunte: "outro projeto do ecossistema usaria isso?".

## Github

- 1. Não faça push, commit, PR ou merge sem o pedido do usuário.
- 2. Caso seja pedido para fazer push, verifique se não há nenhuma credencial exposta.
- 3. Branch por assunto: `feat/`, `fix/`, `docs/` ou `chore/` seguido de um nome curto.
- 4. Commit diz o que muda e por quê, no imperativo e curto. Um commit é uma mudança coesa.
- 5. PR pequeno e de escopo único: se misturou assuntos, divida.
- 6. Antes de pedir merge, confirme que build e testes passam e que não há segredo no diff.
- 7. Não reescreva histórico de branch compartilhada (force push) sem o pedido do usuário.
- 8. Não versione arquivo gerado, binário ou dependência baixada (`build/`, `.venv/`, `node_modules/`, `.env`). Confira o `.gitignore` antes de commitar.

# Cursor

As regras do editor fazem parte do padrão e ficam versionadas. Projeto sem
`.cursor/rules/` está incompleto.

- 1. `.cursor/rules/` é versionado. `.gitignore` não ignora `.cursor`; o que é local (`mcp.json`) não entra.
- 2. Sempre existe uma regra com `alwaysApply: true` que manda ler `README.md`, `AGENTS.md` e `docs/PATTERN.md`, nesta ordem.
- 3. A regra aponta para a fonte, não copia o conteúdo: `AGENTS.md` é a fonte; o `.mdc` só redireciona e destaca o que a regra geral não alcança.
- 4. Regra por área usa `globs` (backend, frontend, docs) e cobre o risco daquela área: envelope, filtro de acesso, tokens de tema, paginação.
- 5. Regra não contradiz `AGENTS.md`. Mudou a regra do padrão, muda `AGENTS.md` e o `.mdc` no mesmo commit.
- 6. `application/` já nasce com `.cursor/rules/` próprio; o fork pode acrescentar regra, nunca remover a base.

# Repositório (fork)

O modelo é **fork**: um repositório por projeto, já com o padrão e o esqueleto
funcionando. Não existe instalação do padrão por git nem cópia de pasta.

- 1. O padrão vive em `packages/` (`atena_pattern`, `atena_ui`) e não conhece o produto.
- 2. O produto vive em `application/` (`backend`, `frontend`) e é o único lugar onde entra domínio.
- 3. `application/*` consome `packages/*` por caminho (`tool.uv.sources`, `pubspec.yaml`), nunca por versão publicada.
- 4. Correção transversal é feita em `packages/`, não no produto. Se o produto precisou de um contorno, o núcleo está incompleto.
- 5. O fork não vira pull request contra a base com mudança de domínio. Melhoria de padrão volta para a base; produto fica no fork.
- 6. Nada de `templates/`: o esqueleto é o próprio `application/`, versionado com o padrão.
- 7. `docker compose` da raiz é o caminho de execução do fork: `make up` sobe banco, API e app. Dockerfile novo só para serviço que não seja um desses.
- 8. Variável nova de execução entra no `.env.example` da raiz e no `environment` do compose (ou no `.env` do backend, se for só local).

# Relação com o projeto

O projeto que consome o padrão:

- lê este arquivo e a documentação de `docs/`;
- mantém `.cursor/rules/` versionado;
- registra as próprias áreas no motor de permissões;
- define a própria paleta no `atena_ui`;
- mantém um `AGENTS.md` próprio apenas com o que é **do domínio** dele, sem
  repetir as regras daqui.

---

# Modern Diary — domínio

Este fork é o produto de referência do padrão. Tudo o que é transversal já está em
`packages/`; o que segue é só do Modern Diary.

## Onde fica o quê

```text
packages/atena_pattern/   envelope, erros, paginação, sessão, usuários, credenciais, acesso
packages/atena_ui/        tema, tokens, TOAT, componentes, níveis de sensibilidade
application/backend/      agenda, notas, conhecimentos, metas, tags, países, feriados, busca, auditoria
application/frontend/     telas, controllers, strings e paleta da marca
```

- Área nova: entra em `application/backend/app/core/areas.py` (enum + `register_areas`) e no
  enum `PermissionArea` de `application/frontend/lib/src/core/domain/sensitivity_level.dart`.
  Nada muda no motor de permissões.
- Widget novo: nasce em `packages/atena_ui`. O app não cria componente genérico.
- Regra de negócio nova: serviço no back. O front não decide nada.

## Áreas protegidas

`conhecimentos`, `notas`, `metas`, `dias` e `atividades`. São os valores que aparecem na
API e no formulário de credencial. O prefixo do token de integração do Modern Diary é
`mds_` (`secret_token_prefix` em `app/core/config.py`).

## Agenda e leitura do dia

- O dia abre em leitura: nota, atividade, tag e nível só aparecem depois do botão
  **Editar**. Ao editar uma nota, o `MarkdownEditor` abre já no texto puro (`startInEdit`).
- Markdown aparece sempre renderizado e é editado no `MarkdownEditor` do package, nunca em
  um `TextField` cru.
- Feriado é status do dia, em laranja; não é nota nem atividade.

## Navegação entre registros

- Tag, meta, conhecimento e dia aparecem clicáveis onde forem citados; o mesmo vale para
  cada uso listado dentro de uma tag.
- Quem troca de área é a `HomeScreen`, por um único `HomeNavigation` (`openTag`,
  `openGoal`, `openKnowledgeItem`, `openDay`). A área de origem só dispara o pedido e não
  conhece a navegação das outras.
- O destino abre o registro pelo parâmetro de foco (`focusTag`, `focusGoalId`,
  `focusItemId`, `focusDay`) e devolve o pedido consumido em `onFocusHandled`, para não
  reabrir a cada rebuild.
- Modal fecha antes de navegar: `Navigator.maybePop()` e então o pedido.

## Documentação do produto

`README.md` descreve as telas e os endpoints. `docs/PLAN.md` é o backlog (a IA deve
desconsiderar esse arquivo ao construir). `docs/PATTERN.md`, `docs/BACKEND.md`,
`docs/FRONTEND.md` e `docs/CHECKLIST.md` documentam o padrão que este fork consome.

## Credenciais de teste

Não há usuário pré-criado. O primeiro cadastro vira `ADMIN`; o segundo, `USER`.
Teste local: `admin` / `admin1234` e `user` / `user1234`.
