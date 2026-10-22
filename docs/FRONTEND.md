# Frontend com o padrão

Como montar um app Flutter usando `atena_ui`.

## 1. Estrutura

```text
app/
├── lib/
│   ├── main.dart
│   └── src/
│       ├── app.dart              MaterialApp, tema, TOAT e navegação raiz
│       ├── core/
│       │   ├── config/           URL da API, informações do app
│       │   ├── network/          ApiClient, ApiEnvelope, ApiException
│       │   ├── preferences/      tema, avatar, preferências locais
│       │   └── strings/          todo texto visível
│       └── features/
│           └── <feature>/
│               ├── data/         repositório e DTO
│               ├── domain/       modelo e regra de apresentação
│               └── presentation/ controller, tela e widgets
└── test/
```

Feature não importa outra feature. Quem troca de área é a tela raiz, por um único
objeto de navegação.

## 2. Package

```yaml
dependencies:
  atena_ui:
    path: ../../packages/atena_ui
```

Regras:

- todo widget novo nasce no package;
- o package não faz HTTP, não lê armazenamento e não conhece idioma;
- identidade (paleta, ícone, textos) entra por parâmetro;
- widget de domínio fica no app (um `ActivityTile` de agenda não é padrão).

## 3. Tema e TOAT

Registre o tema uma única vez e envolva o app com o `ToatHost`:

```dart
const palette = AppPalette.example.copyWith(
  brand: Color(0xFF...),
  brandDeep: Color(0xFF...),
  brandSoft: Color(0xFF...),
);

MaterialApp(
  theme: AppTheme.light(palette: palette),
  darkTheme: AppTheme.dark(palette: palette),
  themeMode: preferences.themeMode,
  builder: (context, child) => ToatHost(
    controller: toatController,
    child: child ?? const SizedBox.shrink(),
  ),
  home: const HomePage(),
);
```

Cor, espaçamento e duração só pelos tokens. Se o token não existe, crie no tema.

## 4. Cliente do envelope

O cliente HTTP fica no app (o package não faz rede). Ele sempre lê o mesmo
envelope e transforma `success: false` em `ApiException` com o `code` do back.

```dart
class ApiClient {
  ApiClient({required String baseUrl, required this.tokenProvider, http.Client? httpClient});

  Future<ApiEnvelope<T>> get<T>(
    String path, {
    required T Function(Object? data) parse,
    Map<String, String>? query,
  });
}
```

Regras do cliente:

- manda `Authorization: Bearer <token>` quando houver sessão ou credencial;
- manda `X-Client-Offset-Minutes` com o fuso de quem usa o app;
- decodifica o envelope, lança `ApiException(code, message, errors)` quando
  `success` é falso;
- timeout explícito e erro de rede com `code` próprio (`NETWORK_ERROR`);
- não conhece regra de negócio.

O `ApiException.code` é o que a tela usa para decidir (nunca o texto). O
`ApiEnvelope.meta` é a única fonte de paginação e contadores.

## 5. Lista e estados

Toda lista:

1. carrega a primeira página;
2. lê `meta` e guarda `next_cursor`/`has_more` ou `page`/`total_pages`;
3. busca a próxima sob demanda;
4. usa debounce na busca e manda filtro/ordenação por query param;
5. cobre carregando, vazio, erro e sucesso com `StatusView`.

Nunca filtre em memória uma lista paginada; nunca use `data.length` como total.

## 6. Ações e notificação

- ação destrutiva: confirmação nomeando o alvo (`AppConfirmDialog` com `danger`);
- ação de risco moderado: confirmação leve ou desfazer (`warning`);
- durante a ação: botão desabilitado com `isLoading`;
- resultado: sucesso/falha pelo TOAT; erro que exige decisão no próprio campo;
- nunca duplo clique, nunca loading travado.

## 7. Strings e acessibilidade

- todo texto visível no arquivo de strings do app;
- o package recebe os rótulos por parâmetro;
- ícone e botão têm rótulo semântico;
- alvo de toque confortável (`AppSpacing.minTouchTarget`) e contraste legível.

## 8. Sensibilidade

Se o projeto usa credenciais e níveis:

```dart
SensitivitySelector(
  label: strings.level,
  selected: level,
  labelOf: (value) => strings.sensitivityLabel(value.apiValue),
  onChanged: (value) => setState(() => level = value),
);
```

O front não decide acesso: ele exibe o que veio. O back filtra por área e nível e
responde 404 para registro acima do limite.

## 9. Testes

- controller e repositório: teste com dados falsos (`test/support/fake_*`);
- widget: teste de estado (carregando, vazio, erro, sucesso) e de ação;
- package: teste de cada componente público.

```bash
flutter test
```
