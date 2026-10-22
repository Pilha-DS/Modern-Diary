# atena_ui

Tema, tokens, TOAT e widgets reutilizáveis do ecossistema Atena. O package não
conhece a aplicação: não faz HTTP, não acessa armazenamento, não conhece idioma
nem identidade — recebe dado por parâmetro e devolve evento por callback.

## Instalação

O package mora em `packages/atena_ui` e é consumido por `application/frontend`
por caminho, no mesmo repositório:

```yaml
dependencies:
  atena_ui:
    path: ../../packages/atena_ui
```

Mexer aqui reflete no app na hora, sem publicar versão.

## Tema

Cada projeto define a própria paleta. `AppPalette.example` serve de ponto de
partida; troque a identidade com `copyWith` ou monte a paleta completa.

```dart
const palette = AppPalette.example; // ou AppPalette.example.copyWith(brand: ...)

MaterialApp(
  theme: AppTheme.light(palette: palette),
  darkTheme: AppTheme.dark(palette: palette),
  themeMode: ThemeMode.system,
  builder: (context, child) => ToatHost(
    controller: toatController,
    child: child ?? const SizedBox.shrink(),
  ),
  home: const HomePage(),
);
```

Sem `AppSemanticColors` registrado no tema, os widgets que leem a extensão falham
em debug. Widget que precisa de identidade recebe o ícone ou o texto por
parâmetro (por exemplo, `AppLogo(icon: ...)`).

## Estrutura

```text
lib/src/
├── theme/        AppPalette, AppTheme, AppSemanticColors, AppSpacing, AppDurations
├── toat/         ToatController, ToatHost, ToatMessage
├── sensitivity/  SensitivityLevel, SensitivitySelector, SensitivityBadge
└── widgets/      componentes reutilizáveis
```

## Componentes

### Layout

- `AppBackground` — fundo com ondas na cor de identidade.
- `AppSurface` — superfície sólida com sombra suave, sem borda.
- `AppHoverCard` — cresce suavemente no hover.
- `AppCardGrid` — grade responsiva com altura uniforme por linha.
- `AppHeader` / `AppFooter` — cabeçalho e rodapé com dados por parâmetro.
- `AppLogo` — marca com ícone por parâmetro.

### Ação e entrada

- `AppButton` — botão único, com `isLoading` que bloqueia duplo envio. Variantes:
  `primary`, `secondary`, `ghost`, `warning` e `danger`.
- `AppTextField` / `AppTextArea` — campos preenchidos, sem borda.
- `AppChoiceChips` / `AppChip` — escolha e etiqueta.
- `AppSwitchRow` / `AppSliderRow` — ajuste com rótulo.
- `AppTimeField` / `AppTimePicker` / `AppClockDial` — horário.
- `AppConfirmDialog` / `AppDialog` — confirmação e modal padrão.

### Conteúdo

- `MarkdownText` / `MarkdownEditor` — markdown renderizado e editável, sem
  dependência externa.
- `StatusView` — estados de carregando, vazio e erro.
- `InlineMessage` — erro que exige decisão, no próprio conteúdo.
- `AppProgressBar` — progresso com contagem.
- `AppChip` — link, conexão ou anexo.
- `MonthCalendar` — calendário de um mês com marcas por parâmetro.
- `NetworkGraph` — rede de nós e arestas com layout de forças.
- `OrbitalMenu` — menu em órbita.
- `RoleBadge` — selo de role com rótulo por parâmetro.

### TOAT

```dart
final toat = ToatController();

toat.show('Salvo com sucesso.', variant: ToatVariant.success);
toat.show(
  'Não foi possível salvar.',
  variant: ToatVariant.error,
  actionLabel: 'Ver detalhes',
  onAction: _showDetails,
);
```

No máximo três mensagens, sem duplicar a mesma em sequência. Sucesso e informação
fecham sozinhos; aviso e erro só fecham por ação do usuário quando exigem
decisão. Erro que exige decisão não é TOAT: use `InlineMessage` ou o erro do campo.

### Sensibilidade

```dart
SensitivitySelector(
  label: 'Nível',
  selected: level,
  labelOf: (value) => strings.sensitivityLabel(value),
  onChanged: (value) => setState(() => level = value),
);

SensitivityBadge(label: strings.sensitivityLabel(level), semanticLabel: ...);
```

`SensitivityLevel.all` só é usado como limite de leitura de credencial; os
níveis de registro são `dataLevels`.

## Testes

```bash
flutter test
```

Cada componente público tem teste em `test/`. Componente novo entra com um
exemplo de uso documentado aqui e um teste.
