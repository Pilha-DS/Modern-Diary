# AGENTS.md

Este é o arquivo base do projeto. A IA deve lê-lo obrigatoriamente antes de construir o software, para fazê-lo de forma eficiente.

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
- 13. Markdown aparece sempre renderizado e é editado no `MarkdownEditor` do package, nunca em um `TextField` cru. No dia, a leitura é o padrão: nota, atividade, tag e nível só aparecem depois do botão **Editar**; ao editar uma nota, o formulário abre já no texto puro (`startInEdit`).

## Ações

Regras para qualquer ação que o usuário executa (botão, menu, gesto).

- 1. Ação destrutiva ou irreversível (excluir conta, apagar histórico, apagar memória) exige confirmação explícita, nomeando o que será apagado, com a cor vermelha.
- 2. Ação de risco moderado (excluir nota, excluir atividade, descartar edição) pede confirmação leve ou desfazer, com a cor amarela.
- 3. Enquanto executa, a ação fica desabilitada com indicador de progresso: nunca permita duplo clique nem duplo envio.
- 4. Toda ação termina em um dos três estados: sucesso (confirmação), falha (mensagem clara) ou cancelada (nada muda).
- 5. Mensagem de erro diz o que aconteceu e o que o usuário pode fazer. Nunca apenas "erro", nunca stack trace.
- 6. Prefira desfazer a confirmar: se a ação é reversível com facilidade, ofereça "desfazer" em vez de bloquear com modal.
- 7. O botão de cancelar nunca fica mais chamativo que o de confirmar.
- 8. Se a ação falhar, a tela não pode ficar em estado inconsistente (nada de item sumido, contador errado ou loading travado).

Qualquer notificação — sucesso, aviso ou erro — é exibida no **TOAT**: a mensagem padrão do projeto, no canto superior direito.

- 9. Toda notificação sai pelo TOAT: mesma posição (direita superior), mesmo formato e mesmo componente. Não crie toast, banner, snackbar ou alerta paralelo na tela.
- 10. O TOAT tem variantes fixas — sucesso, aviso, erro e informação — e a cor de cada uma segue a seção Cores: erro vermelho, aviso amarelo, informação cinza-claro, sucesso sem cor sólida (ícone/elemento de destaque).
- 11. O TOAT traz sempre: ícone da variante, mensagem curta e, opcionalmente, uma ação ("desfazer", "ver detalhes"). Sem título longo, sem parágrafo.
- 12. Sucesso e informação fecham sozinhos (4 a 6 s). Aviso e erro só fecham por ação do usuário quando exigem decisão.
- 13. Erro que exige decisão não é TOAT: usa confirmação ou mensagem no próprio formulário, no campo que falhou. TOAT é para aviso passageiro.
- 14. No máximo 3 TOATs na tela, um por vez na mesma posição; o mais antigo sai primeiro. O TOAT nunca cobre header, botão principal nem conteúdo essencial.
- 15. O texto do TOAT diz o que aconteceu e o que fazer, em uma linha. Nunca exibe código de erro cru, stack trace ou nome de tabela — detalhe técnico só em "ver detalhes".
- 16. O TOAT é um componente único do package, criado uma vez e reutilizado. Chamada duplicada da mesma mensagem em sequência é agrupada, não empilhada.

## Cores

As cores são essenciais para o projeto, pois definem o que ele é e o que ele não é. É obrigatório seguir estas regras.

- 1. O projeto deve ser elegante: evite cores sólidas e prefira o uso de sombras suaves. Evite sombras muito fortes e use cores sólidas apenas em casos muito específicos.
- 2. A cor vermelha deve ser usada somente para ações temerárias ou erros (excluir conta, apagar histórico, apagar memória, erros etc.).
- 3. A cor amarela deve ser usada somente para avisos (excluir nota, excluir atividade, toasts, mensagens leves etc.).
- 4. A cor verde é o padrão visual do projeto, mas deve ser usada apenas para expressar a identidade dele, não em qualquer lugar (destaque da logo, ondas no fundo, ondas no header etc.).
- 5. A cor cinza-médio, assim como a verde, é padrão do projeto; porém, diferente da verde, é a mais comum (fundo, header, área comum da logo etc.).
- 6. A cor cinza-claro é o padrão para botões sem efeito. Deve ser usada por padrão (cancelar ação, texto etc.).
- 7. A cor azul-médio-claro é o padrão para botões de aceitar ações não temerárias (criar tarefa, criar atividade etc.).
- 8. Cores diferentes das anteriores podem ser usadas quando fizer sentido, mas devem ser evitadas (indefinido).

## Navegação

Toda referência a outro registro é link, não texto solto: tag, meta, conhecimento e dia levam ao registro.

- 1. Tag, meta, conhecimento e dia aparecem clicáveis onde forem citados; o mesmo vale para cada uso listado dentro de uma tag.
- 2. Quem troca de área é a `HomeScreen`, por um único `HomeNavigation` (`openTag`, `openGoal`, `openKnowledgeItem`, `openDay`). A área de origem só dispara o pedido e não conhece a navegação das outras.
- 3. O destino abre o registro pelo parâmetro de foco (`focusTag`, `focusGoalId`, `focusItemId`, `focusDay`) e devolve o pedido consumido em `onFocusHandled`, para não reabrir a cada rebuild.
- 4. Modal fecha antes de navegar: `Navigator.maybePop()` e então o pedido.
- 5. Referência sem destino não é link: o chip fica sem ação, sem chevron e sem promessa visual.

## Package

O projeto usa packages para simplificar a reutilização de código. O uso do package é obrigatório.

- 1. Antes de criar qualquer widget, verifique se ele já existe no package; se existir, reutilize-o.
- 2. Se o padrão não existir no package e for necessário, crie-o dentro do package para que possa ser reutilizado por outros.
- 3. O package não conhece a aplicação: não importe tela, rota ou regra de negócio de dentro dele.
- 4. Componente do package não faz HTTP nem acessa armazenamento: recebe dado por parâmetro e devolve evento por callback.
- 5. Todo componente público do package tem um exemplo de uso documentado.

# Regras Backend

## Geral

- 1. Mantenha pastas e arquivos bem separados e organizados: crie um arquivo para cada responsabilidade, ou use um que já faça aquilo. Separe as pastas em categorias para evitar muitos arquivos no mesmo local (exemplos: security, activities, agenda etc.).
- 2. Não pode haver arquivos monolíticos, com milhares de linhas: separe em módulos (mas não crie um arquivo por função/método).
- 3. Cada camada tem uma responsabilidade: rota recebe, valida e responde; serviço aplica regra de negócio; repositório fala com o banco. Nada de SQL na rota nem regra no repositório.
- 4. Toda entrada da API é validada por schema antes de chegar na regra de negócio. Nunca confie no que o front mandou.
- 5. Toda alteração de banco é uma migration versionada: não altere o banco na mão nem edite migration já aplicada.
- 6. Toda consulta é filtrada pelo usuário autenticado. O identificador do usuário vem da sessão/token, nunca do corpo da requisição.
- 7. Segredos vêm de variável de ambiente, nunca do código. A exceção são as credenciais de teste, que seguem a regra geral.
- 8. Erro segue um formato único de resposta e não vaza detalhe interno (stack trace, SQL, nome de tabela).
- 9. Regra de negócio tem teste. Bug corrigido ganha um teste que reproduz o bug.
- 10. Operação demorada (IA, e-mail, importação) roda em background e devolve um estado para o front acompanhar; não bloqueie a requisição.
- 11. Log não carrega dado sensível: nada de senha, token, conteúdo de diário ou dado pessoal.

## Acesso por credencial (secrets)

O dono da conta usa a sessão (JWT) e enxerga tudo o que é dele. Integrações usam uma
secret, com permissões independentes por área. A decisão de acesso fica em um único lugar
(`app/core/access.py`: `Actor` + `AccessGuard`); serviço nenhum inventa a própria regra.

- 1. Toda leitura filtra o nível de sensibilidade no banco (`guard.visible(area)`): lista,
  detalhe, grafo, contagem e `meta.total` usam o mesmo critério. Registro acima do nível
  responde 404, nunca 403, para não revelar que existe.
- 2. Região sem permissão configurada responde `AREA_NOT_PERMITTED`. Nada é liberado por
  padrão.
- 3. Criação depende só de `create`, em qualquer nível. Criar não dá leitura nem escrita
  depois: as próximas requisições continuam sujeitas ao nível de leitura.
- 4. Escrita e exclusão exigem `write` **e** o registro dentro do nível lido. O nível de um
  registro só pode ser alterado até o limite de leitura da credencial.
- 5. Dado ligado (título de conexão, título de meta) também é filtrado pela área e nível de
  quem lê. Um registro escondido não vaza por dentro de outro.
- 6. Toda decisão negada e toda criação/alteração/exclusão feita por secret vai para
  `secret_audit_logs` com área, ação, resultado, alvo e `request_id`.
- 7. Área nova: inclua no enum `Area`, no registro `AREA_SENSITIVITY`, na coluna de
  sensibilidade do modelo e no filtro do serviço. O motor de permissões não muda.
- 8. Endpoint que gerencia secrets, usuários ou tags exige sessão. Secret nunca administra
  credencial, role nem tag.
- 9. O token da secret (`mds_...`) nunca é gravado em texto: só o hash SHA-256 e o final,
  que serve de pista visual. O texto puro aparece apenas na criação e na rotação.

## Dados de referência (países)

País é catálogo fixo, não cadastro do usuário: ninguém cria, edita ou apaga país pela API.

- 1. A fonte única é `app/data/countries.json`, versionado no repositório. A migration cria
  a tabela `country` e insere a lista lida desse arquivo; os testes usam o mesmo arquivo.
- 2. Nada de digitar nome de país: o usuário escolhe uma linha da tabela. Deduzir país a
  partir de texto livre gera duplicata e grafia divergente.
- 3. Listagem de referência segue a paginação padrão (`page`/`per_page`, teto do servidor) e
  aceita busca por nome, nome oficial, grafia nativa e código ISO.
- 4. Novo dado de referência segue este caminho: arquivo em `app/data`, modelo só com
  leitura, `GET` paginado, sem POST/PATCH/DELETE.

## Feriados (fonte externa)

Feriado é um **status do dia**, não nota nem atividade: entra no calendário em laranja e
no painel do dia pelo campo `holiday` da agenda. A fonte é externa e gratuita
(Nager.Date, ano inteiro por país), mas a agenda nunca a consulta ao abrir a tela.

- 1. A fonte só é chamada pela sincronização (`POST /api/v1/holidays/sync`), disparada
 pelo botão **Puxar feriados** nos Ajustes. O resultado é gravado na tabela `holiday`.
- 2. A nacionalidade vem dos Ajustes; sem ela, o app pede que o usuário escolha uma antes
 de chamar a API. País não habilitado responde `HOLIDAY_COUNTRY_NOT_ENABLED`.
- 3. A sincronização cobre o ano corrente e o seguinte, substitui os feriados anteriores
 do usuário e só troca o banco depois de buscar tudo: falha da fonte não deixa estado
 pela metade e responde `HOLIDAY_SOURCE_UNAVAILABLE`.
- 4. Só feriado global entra; feriado regional não representa o país inteiro.
- 5. A leitura é sempre filtrada pelo usuário autenticado; feriado não tem nível de
 sensibilidade (é público). O nome exibido é o `local_name`, com `name` como reserva.
- 6. A cor do feriado é o token `holiday`/`holidaySoft` do tema — nunca laranja escrito
 no widget. Habilitar um país novo é acrescentá-lo em `app/data/holidays.py`; o motor
 de permissões e a agenda não mudam.

Todo retorno da API — sucesso, erro, validação ou lista — usa o **mesmo envelope**. A forma da resposta nunca muda; só os valores mudam.
- 12. Envelope obrigatório, com estes campos e nesta ordem: `code`, `success`, `data`, `message`, `errors`, `meta`, `request_id`, `timestamp`.
- 13. Nenhum campo é omitido. Quando não se aplica: `data` = `null`, `message` = `null`, `errors` = `[]`, `meta` = `{}`. O front nunca precisa adivinhar se a chave existe.
- 14. `code` é o contrato: string estável em `SCREAMING_SNAKE_CASE`. O front decide o que fazer pelo `code`, nunca pelo texto de `message`.
- 15. `success` é booleano e sempre coerente com o status HTTP e com `code`.
- 16. `data` é só o payload (objeto, lista ou `null`). Nunca carrega mensagem de status nem `success` duplicado.
- 17. `message` é texto para humano, curto e opcional. `errors` é a lista de falhas por campo, no formato `{ field, code, message }`.
- 18. `meta` carrega paginação e contadores: `page`, `per_page`, `total`, `total_pages` no modo offset, ou `next_cursor` e `has_more` no modo cursor. Lista vazia é `data: []` com `meta.total: 0` — não é erro.
- 19. `request_id` identifica a requisição para correlacionar com o log; `timestamp` é ISO 8601 em UTC, com `Z`.
- 20. O status HTTP continua correto e coerente com `code` (400, 401, 403, 404, 409, 422, 500). O envelope complementa o status, não o substitui.
- 21. Se o padrão ainda não existir no projeto, crie-o em um módulo único (ex.: `core/responses`) e use em **todos** os endpoints. Se já existir, use o existente — nunca crie um segundo formato.

Sucesso:

```json
{
  "code": "ATIVIDADE_CRIADA",
  "success": true,
  "data": { "id": "uuid", "title": "Estudar FastAPI" },
  "message": "Atividade criada com sucesso.",
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
  "message": "Não foi possível salvar a atividade.",
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
  "code": "ATIVIDADES_LISTADAS",
  "success": true,
  "data": [],
  "message": null,
  "errors": [],
  "meta": { "page": 1, "per_page": 20, "total": 0, "total_pages": 0 },
  "request_id": "req_01H...",
  "timestamp": "2026-10-19T22:59:00Z"
}
```

Paginação e volume de dados. Regra de ouro: quem controla a paginação é o **back**. O front pede; o back decide quanto, como e até quando entregar.

- 22. Nenhum endpoint de listagem devolve a tabela inteira. Toda listagem é paginada, sem exceção, mesmo que hoje a tabela tenha 3 linhas.
- 23. `page` e `per_page` são validados por schema, sempre positivos. O servidor define o padrão (ex.: 20) e o teto (ex.: 100); pedido acima do teto é cortado no teto, não é erro.
- 24. O `offset` é calculado no servidor. Nunca aceite `offset`, `skip` ou `limit` crus do cliente sem validar contra o teto.
- 25. A paginação acontece no banco (`LIMIT`/`OFFSET` ou `WHERE` + cursor). Nunca traga tudo para a aplicação e corte depois; nada de `SELECT *` de tabela inteira em produção.
- 26. Lista grande, ou que muda enquanto é lida (agenda, histórico, feed, notificações), usa paginação por cursor (`cursor` + `limit`), não offset, para não duplicar nem pular item.
- 27. O `meta` informa a paginação: `page`, `per_page`, `total`, `total_pages` no modo offset; `next_cursor` e `has_more` no modo cursor. O front nunca deduz isso sozinho.
- 28. Ordenação é sempre determinística: toda consulta ordena por uma coluna e desempata pela chave primária. Sem ordem estável, a paginação repete ou perde registro.
- 29. `SELECT` só das colunas usadas na resposta. Relação 1:N não é carregada item por item dentro de laço (N+1): use join, eager loading ou consulta em lote.
- 30. Toda coluna usada em filtro, ordenação ou junção tem índice. Busca textual usa índice apropriado; `LIKE '%termo%'` sobre tabela grande é proibido.
- 31. `COUNT` caro não roda a cada página: nesse caso `meta` traz `has_more` (ou total aproximado) em vez de `total` exato, sem mudar a forma do envelope.
- 32. Agregação, relatório, exportação e IA não rodam na requisição síncrona: vão para background (regra 10) e o front acompanha por um endpoint de estado. Resultado grande também é paginado ou entregue como arquivo.
- 33. Importação e operação em massa entram em lotes com transação por lote, com limite de tamanho validado no servidor — nunca um insert/update gigante nem um payload sem teto.
- 34. Rota cara (IA, busca, exportação, sincronização) tem limite de frequência por usuário e devolve `code` próprio quando excede, sem derrubar a fila.
- 35. Consulta lenta é logada com duração e `request_id` para achar o gargalo. Timeout do servidor e tamanho máximo de corpo/upload são explícitos, não infinitos.

# Regras Gerais

As regras gerais normalmente são as mais importantes. São obrigatórias.

- 1. Nunca coloque regras de negócio dentro do front. Podem vir a ocorrer pontos de ataque.
- 2. Sempre coloque as credenciais de teste no final para o usuário poder testar.
- 3. Faça o menos possível para fazer o que foi pedido: somente o necessário para funcionar.
- 4. Mantenha o código o mais simples possível para fazer o que precisa ser feito.
- 5. Nome de variável, função e arquivo diz o que aquilo é: sem abreviação obscura e sem `data`, `aux` ou `temp`.
- 6. Não instale dependência sem necessidade: se resolve com o que já existe, resolva com o que já existe.
- 7. Não deixe código morto, comentado ou `TODO` sem dono: remova ou registre a tarefa.
- 8. Todo fluxo funciona do zero: se exige um passo manual não documentado, não está pronto.
- 9. Ao corrigir, conserte a causa e não o sintoma: se o mesmo bug pode reaparecer por outro caminho, feche o caminho.
- 10. Um padrão por assunto. Se o projeto já tem padrão para aquilo (retorno de API, TOAT, erro, estado de tela, nome de pasta), use o existente e siga exatamente a forma dele. Se ainda não tem, crie **um** padrão reutilizável, registre aqui e passe a usá-lo. Nunca conviva com dois formatos para a mesma coisa.
- 11. O padrão criado vale para casos futuros, não só para o atual: nasce reutilizável (no package ou em módulo comum), não copiado de tela em tela.

## Github

As regras do Github são importantes para manter a estrutura e a organização.

- 1. Não faça push, commit, PR ou merge sem o pedido do usuário.
- 2. Caso seja pedido para fazer push, verifique se não há nenhuma credencial exposta.
- 3. Branch por assunto: `feat/`, `fix/`, `docs/` ou `chore/` seguido de um nome curto.
- 4. Commit diz o que muda e por quê, no imperativo e curto. Um commit é uma mudança coesa.
- 5. PR pequeno e de escopo único: se misturou assuntos, divida.
- 6. Antes de pedir merge, confirme que build e testes passam e que não há segredo no diff.
- 7. Não reescreva histórico de branch compartilhada (force push) sem o pedido do usuário.
- 8. Não versione arquivo gerado, binário ou dependência baixada (`build/`, `node_modules/`, `.env`). Confira o `.gitignore` antes de commitar.
