# modern_diary_ui

Tema, tokens, componentes e TOAT reutilizáveis do Modern Diary. O package não conhece a
aplicação: não faz HTTP, não acessa armazenamento e recebe dados por parâmetro.

## Uso

Adicione o package ao `pubspec.yaml` do app:

```yaml
dependencies:
  modern_diary_ui:
    path: ../packages/modern_diary_ui
```

Registre o tema uma única vez e envolva o app com o `ToatHost`:

```dart
MaterialApp(
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  themeMode: preferences.themeMode,
  builder: (context, child) => ToatHost(
    controller: toatController,
    child: child ?? const SizedBox.shrink(),
  ),
  home: const HomePage(),
);
```

Sem `AppTheme.light()` os widgets que usam `AppSemanticColors` falham no modo debug.
`AppTheme.dark()` traz a mesma paleta no escuro; os widgets leem tudo do tema, então
basta o `themeMode` para trocar.

## Componentes

### AppBackground

Fundo claro com ondas suaves na cor de identidade.

```dart
const AppBackground(child: SafeArea(child: HomeContent()));
```

### AppSurface

Superfície sólida com sombra suave, sem borda. `shadowColor` troca a cor da
sombra padrão — o mês atual usa a sombra azul do tema para ficar em destaque.

```dart
const AppSurface(
  child: Text('Conteúdo'),
);

AppSurface(
  shadowColor: AppSemanticColors.of(context).highlightShadow,
  child: const MonthCalendar(
    compact: true,
    year: 2026,
    month: 10,
    monthName: 'Outubro',
    weekdayLabels: ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'],
  ),
);
```

### AppHoverCard

Faz o cartão crescer suavemente no hover, indicando que o conteúdo está ativo.
O toque continua indo para o que está dentro do cartão.

```dart
AppHoverCard(
  child: AppSurface(
    child: MonthCalendar(
      compact: true,
      year: 2026,
      month: 10,
      monthName: 'Outubro',
      weekdayLabels: const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'],
      onDaySelected: openDay,
    ),
  ),
);
```

### AppButton

Botão único do projeto. `isLoading` desabilita o botão e evita duplo envio.

```dart
AppButton(
  label: 'Salvar',
  icon: Icons.check_rounded,
  onPressed: _isSubmitting ? null : _save,
  isLoading: _isSubmitting,
);

AppButton(
  label: 'Excluir',
  variant: AppButtonVariant.danger,
  onPressed: _confirmDelete,
);
```

Variantes: `primary` (ação comum), `secondary` (ação leve), `ghost` (sem fundo),
`warning` (confirmação de ação reversível) e `danger` (somente ação temerária).

### AppProgressBar

Barra de progresso sem borda, com a contagem ao lado. O valor é uma fração de 0 a 1;
o texto e o rótulo semântico vêm de fora.

```dart
AppProgressBar(
  value: 2 / 5,
  label: '2/5',
  semanticLabel: 'Progresso da meta Aprender Flutter: 2 de 5',
);
```

### AppTextArea

Campo multilinha, preenchido e sem borda, para notas e textos longos.

```dart
AppTextArea(
  controller: _noteController,
  hint: 'Markdown: # título, **negrito**, - item',
  minLines: 6,
  onChanged: _markDirty,
);
```

### MonthCalendar

Calendário de um mês, sem bordas. Cada dia recebe uma marca (`CalendarDayMark`) e
o toque devolve o número do dia. Em `compact` vira a prévia usada na visão anual:
ocupa sempre seis semanas, para todos os meses ficarem com a mesma altura.
Os nomes de mês e os rótulos dos dias da semana vêm de fora, para o package não
conhecer o idioma.

```dart
MonthCalendar(
  year: 2026,
  month: 10,
  monthName: 'Outubro',
  weekdayLabels: const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'],
  marks: {
    19: const CalendarDayMark(hasNote: true, activitiesTotal: 2, activitiesDone: 1),
    12: const CalendarDayMark(holiday: 'Nossa Senhora Aparecida'),
  },
  selectedDay: DateTime(2026, 10, 19),
  today: DateTime(2026, 10, 19),
  daySemanticLabel: (day, mark) => '${day.day} de outubro',
  onDaySelected: (day) => selectDay(day),
  dayPreview: (context, day, mark) => DayPreview(day: day),
);

// Prévia anual, tocável por inteiro.
MonthCalendar(
  compact: true,
  year: 2026,
  month: 10,
  monthName: 'Outubro',
  weekdayLabels: const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'],
  cardSemanticLabel: 'Outubro de 2026',
  onTap: openMonth,
);
```

Cada estado tem uma cor própria: o dia atual fica verde, o dia aberto fica azul
sólido e as marcas do dia (nota, atividade, prioridade alta e feriado) usam fundos
suaves diferentes. Feriado vem antes das marcas de conteúdo e usa o laranja do tema
(`holiday`/`holidaySoft`) — `CalendarDayMark(holiday: 'Finados')`. Cada dia tocável
ganha apoio visual em cinza-claro no hover. Quando
o dia já tem fundo (hoje, marcado ou selecionado), o hover entra como anel, para
a cor dele não sumir.

`dayPreview` monta um mini-modal ao lado do dia depois do tempo de hover do tema
(`AppDurations.hoverTooltip`). O conteúdo vem de fora, por callback: o package
posiciona o painel à direita da célula e o vira para a esquerda quando não há
espaço na tela, com largura máxima de `AppSpacing.hoverPreviewWidth`. O painel
ignora ponteiros, então mover o mouse entre dias troca a prévia sem travar o
hover; dia sem marca não abre prévia.

### AppCardGrid

Grade responsiva com **altura uniforme por linha**. Calcula as colunas a partir
da largura mínima e estica todos os cartões da linha até o mais alto — o rodapé
do cartão deve usar um `Spacer` antes das ações para ficar sempre embaixo.

```dart
AppCardGrid(
  minCardWidth: 200,
  maxColumns: 4,
  children: [
    for (final item in items) KnowledgeCard(item: item),
  ],
);
```

### AppHeader

Cabeçalho padrão: identidade à esquerda, selo opcional e avatar à direita. O
avatar mostra as iniciais quando não há foto e abre o menu escondido com os
itens recebidos — é por ali que o usuário chega às configurações. Com
`onLogoPressed`, a marca vira um atalho (o app usa para voltar ao início); sem
ele, a marca é só visual.

```dart
AppHeader(
  title: 'Modern Diary',
  subtitle: 'jonathan',
  avatarLabel: 'jonathan',
  avatarImage: preferences.avatarImage,
  avatarTooltip: 'Perfil e configurações',
  logoTooltip: 'Ir para Início',
  onLogoPressed: goToDashboard,
  trailing: RoleBadge(role: 'USER', label: 'USUÁRIO'),
  menuItems: [
    AppHeaderMenuItem(
      icon: Icons.settings_outlined,
      label: 'Configurações básicas',
      onSelected: openSettings,
    ),
  ],
);
```

### AppFooter

Rodapé com a identificação de quem fez o projeto e os contatos. Os dados vêm
por parâmetro, então o app decide de onde ler (o Modern Diary usa constantes de
build, trocáveis por `--dart-define`).

```dart
const AppFooter(
  appName: 'Modern Diary',
  tagline: 'Seu dia, organizado.',
  note: 'Criado por Jonathan',
  items: [
    AppFooterItem(icon: Icons.mail_outline_rounded, text: 'eu@exemplo.com'),
  ],
);
```

### MarkdownText

Renderiza um subconjunto de markdown sem dependência externa: títulos, listas,
checklists, citação, código e negrito/itálico/link em linha.

```dart
const MarkdownText(
  '## Terça\n\n- [x] Estudar\n- [ ] Correr',
  emptyText: 'Nenhuma nota neste dia.',
);
```

### MarkdownEditor

Campo de markdown que nasce renderizado: clicar no texto mostra o markdown puro
para editar e, ao sair, o texto volta a ser renderizado. A barra de comandos
altera o texto no cursor e o rodapé opcional conta palavras e caracteres.
Recebe o `controller` por parâmetro e devolve o texto por callback.

```dart
MarkdownEditor(
  controller: _contentController,
  labels: const MarkdownEditorLabels(
    label: 'Conteúdo',
    hint: 'Markdown: # título, **negrito**, - item',
    emptyPreview: 'O texto aparece aqui.',
    edit: 'Clique para editar',
    done: 'Concluir edição',
    commands: {
      MarkdownCommand.heading: 'Título',
      MarkdownCommand.bold: 'Negrito',
      MarkdownCommand.checklist: 'Checklist',
    },
    countLabel: _countLabel,
  ),
  onEditingComplete: _save,
);
```

### ActivityTile

Linha de atividade com concluir, horário, prioridade e excluir. O dado entra por
parâmetro e os eventos saem por callback.

```dart
ActivityTile(
  title: 'Estudar FastAPI',
  timeLabel: '09:30',
  sensitivityLabel: 'Complexo',
  priority: ActivityPriority.high,
  priorityLabel: 'Alta',
  isDone: false,
  toggleLabel: 'Marcar como concluída',
  deleteLabel: 'Excluir atividade',
  onToggle: toggle,
  onDelete: askDelete,
);
```

### AppConfirmDialog

Confirmação de ação de risco. A variante `warning` (amarela) é para ação
reversível; `danger` (vermelha) só para ação temerária.

```dart
final confirmed = await showAppConfirmDialog(
  context,
  title: 'Excluir atividade?',
  message: 'A atividade "Estudar" será removida deste dia.',
  confirmLabel: 'Excluir',
  cancelLabel: 'Cancelar',
  variant: AppConfirmVariant.warning,
);
```

### AppChip

Etiqueta compacta, sem borda, para links, conexões e anexos. Pode abrir uma ação
(`onTap`) e oferecer remoção (`onDeleted`, sempre com rótulo acessível).

```dart
AppChip(
  icon: Icons.hub_outlined,
  label: 'Banco de dados',
  semanticLabel: 'Abrir Banco de dados',
  onTap: openRelated,
  deleteLabel: 'Remover conexão com Banco de dados',
  onDeleted: removeRelation,
);
```

### NetworkGraph

Rede de nós e arestas com layout de forças, para qualquer relação muitos-para-muitos.
O componente não conhece a aplicação: recebe nós, arestas e devolve o nó tocado e,
opcionalmente, o par conectado. O tamanho do nó cresce com o `weight`.

```dart
final controller = NetworkGraphController();

NetworkGraph(
  controller: controller,
  semanticLabel: 'Rede de conhecimentos',
  nodes: const [
    NetworkNode(id: '1', label: 'Índices', weight: 3),
    NetworkNode(id: '2', label: 'SQL', weight: 1),
  ],
  edges: const [
    NetworkEdge(source: '1', target: '2'),
  ],
  selectedId: '1',
  onNodeTap: (node) => openDetail(node.id),
  onConnect: (source, target) => connect(source.id, target.id),
  nodePreview: (context, node) => NodePreview(node: node),
);
```

O grafo é interativo:

- arrastar um nó move e **fixa** a posição dele; soltar reaquece a simulação para
  os vizinhos se ajustarem;
- arrastar o fundo desloca a rede e a roda do mouse dá zoom (no toque, dois dedos
  dão zoom);
- hover e seleção destacam o nó e as conexões dele e apagam o resto, para ler a
  vizinhança;
- com `NetworkGraphController.connectMode` ligado, arrastar de um nó até outro
  chama `onConnect`; o alvo é destacado e a linha pontilhada segue o ponteiro.

`NetworkGraphController` guarda os ajustes de força (`NetworkGraphSettings`:
`repulsion`, `linkDistance` e `gravity`, todos multiplicadores a partir de `1`),
o modo de conexão e os comandos `reorganize()` (solta os nós fixados e refaz o
layout), `resetView()` (zoom e deslocamento originais) e `zoomIn()`/`zoomOut()`.
Sem controller, o gráfico usa os ajustes padrão e não expõe comandos. Mudar os
ajustes refaz a simulação a partir das posições atuais, sem perder o lugar dos
nós. O controller também lembra as posições normalizadas da rede
(`rememberedPositionOf`/`rememberPosition`), então desmontar e montar o grafo de
novo — trocar de aba, entrar em tela cheia, voltar — continua o mesmo desenho.

`nodePreview` monta um mini-modal ao lado do nó depois do tempo de hover do tema
(`AppDurations.hoverTooltip`). O conteúdo vem de fora, por callback: o package
posiciona o painel à direita do nó, vira para a esquerda quando não cabe e centra
na vertical, sempre dentro da área do grafo, com largura máxima de
`AppSpacing.hoverPreviewWidth`. O painel ignora ponteiros, então mover o mouse
entre nós troca a prévia sem travar o hover. Sem `nodePreview`, o resumo curto do
`NetworkNode.tooltip` continua aparecendo no lugar.

O grafo precisa de altura definida pelo pai (por exemplo, dentro de um `SizedBox`).
Ocupa o espaço disponível e mantém o desenho proporcional. Quando os nós mudam
(filtro, exclusão ou conexão nova), as posições dos que continuam são preservadas
e só os novos entram.

### NetworkGraphSettingsPanel

O painel **Ajustes da rede** pronto para o `NetworkGraph`: os três `AppSliderRow`
de força e a dica de arrasto, sem estado próprio — quem escuta o controller e
reconstrói o painel é a tela. Os textos chegam por `NetworkGraphSettingsLabels`,
porque o package não conhece o idioma da aplicação.

```dart
ListenableBuilder(
  listenable: controller,
  builder: (context, _) => Stack(
    children: [
      NetworkGraph(controller: controller, nodes: nodes, edges: edges, onNodeTap: open),
      Positioned(
        top: AppSpacing.sm,
        right: AppSpacing.sm,
        child: NetworkGraphSettingsPanel(
          controller: controller,
          labels: const NetworkGraphSettingsLabels(
            repulsion: 'Repulsão',
            linkDistance: 'Distância das conexões',
            gravity: 'Gravidade',
            dragHint: 'Arraste os nós para mudar a posição.',
          ),
          maxWidth: 280,
          maxHeight: constraints.maxHeight,
        ),
      ),
    ],
  ),
);
```

### AppSliderRow

Linha de ajuste contínuo com rótulo, valor formatado e `Slider`, sem borda. O
valor exibido também é o que o leitor de tela anuncia, junto do rótulo.

```dart
AppSliderRow(
  label: 'Repulsão',
  icon: Icons.open_in_full_rounded,
  value: settings.repulsion,
  min: 0.3,
  max: 2.4,
  valueLabel: '1,4×',
  onChanged: (value) => update(settings.copyWith(repulsion: value)),
);
```


### AppDialog

Modal padrão do projeto: superfície sólida, título, botão de fechar e conteúdo
rolável. Serve para editar algo sem sair da tela atual. É genérico: o conteúdo
fecha com `Navigator.pop(valor)` e o `Future` devolve esse valor.

```dart
final draft = await showAppDialog<GoalDraft>(
  context,
  title: 'Nova meta',
  closeLabel: 'Fechar',
  child: GoalForm(),
);
```

O `AppDialogSurface` pode ser usado direto quando o modal precisa de um
`Dialog` próprio.

### OrbitalMenu

Bola central de navegação. Abre os itens em órbita no hover, no toque ou pelo
teclado. Funciona igual em tela de toque. Os itens são só ícones, próximos uns
dos outros, e o nome aparece em um tooltip depois de `tooltipWait` (padrão 2s).
Cada item usa a superfície invertida do tema (`contrastSurface`/`contrastInk`),
para o menu saltar do fundo, e o item atual fica na cor da identidade.

```dart
OrbitalMenu(
  semanticLabel: 'Menu de navegação',
  items: [
    OrbitalMenuItem(
      icon: Icons.home_outlined,
      label: 'Início',
      isSelected: true,
      onSelected: openDashboard,
    ),
    OrbitalMenuItem(
      icon: Icons.calendar_month_outlined,
      label: 'Calendário',
      onSelected: openCalendar,
    ),
  ],
);
```

### AppTextField

Campo preenchido, sem borda, com botão de mostrar/ocultar senha.

```dart
AppTextField(
  controller: _passwordController,
  label: 'Senha',
  obscure: true,
  showPasswordLabel: 'Mostrar senha',
  hidePasswordLabel: 'Ocultar senha',
  errorText: _passwordError,
  onSubmitted: (_) => _submit(),
);
```

### InlineMessage

Mensagem no próprio conteúdo para erro que exige decisão. Não é TOAT.

```dart
const InlineMessage(
  message: 'Usuário ou senha incorretos.',
  variant: InlineMessageVariant.error,
);
```

### StatusView

Cobre os estados de carregando, vazio e erro de uma lista ou seção.

```dart
const StatusView.loading(title: 'Carregando usuários...');

StatusView.empty(
  icon: Icons.people_outline_rounded,
  title: 'Nenhum usuário ainda',
  message: 'Assim que alguém se cadastrar, aparecerá aqui.',
);

StatusView.error(
  title: 'Não foi possível carregar',
  message: error.message,
  actionLabel: 'Tentar novamente',
  onAction: _reload,
);
```

### RoleBadge

Badge de role. O texto vem de fora para o package não conhecer o idioma da aplicação.

```dart
RoleBadge(role: 'ADMIN', label: 'ADMIN');
```

### AppLogo

Marca do projeto na cor de identidade.

```dart
const AppLogo(semanticLabel: 'Modern Diary');
```

### TOAT

Notificações no canto superior direito, com no máximo 3 mensagens e fechamento
automático só para `success` e `info`.

```dart
final toat = ToatController();

toat.show('Conta criada com sucesso.', variant: ToatVariant.success);
toat.show(
  'Não foi possível salvar.',
  variant: ToatVariant.error,
  actionLabel: 'Ver detalhes',
  onAction: _showDetails,
);
```

Erro que exige decisão não vai para o TOAT: use `InlineMessage` ou a mensagem do campo.
