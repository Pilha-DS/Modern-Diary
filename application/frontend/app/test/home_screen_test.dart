import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modern_diary/src/core/config/app_info.dart';
import 'package:modern_diary/src/core/network/api_client.dart';
import 'package:modern_diary/src/core/network/auth_token.dart';
import 'package:modern_diary/src/core/preferences/app_preferences.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/agenda/data/agenda_repository.dart';
import 'package:modern_diary/src/features/agenda/data/holidays_repository.dart';
import 'package:modern_diary/src/features/audit/data/audit_repository.dart';
import 'package:modern_diary/src/features/auth/data/auth_repository.dart';
import 'package:modern_diary/src/features/auth/data/session_store.dart';
import 'package:modern_diary/src/features/auth/domain/user.dart';
import 'package:modern_diary/src/features/auth/presentation/auth_controller.dart';
import 'package:modern_diary/src/features/goals/data/goals_repository.dart';
import 'package:modern_diary/src/features/home/presentation/home_screen.dart';
import 'package:modern_diary/src/features/knowledge/data/knowledge_repository.dart';
import 'package:modern_diary/src/features/life/data/life_repository.dart';
import 'package:modern_diary/src/features/knowledge/presentation/knowledge_card.dart';
import 'package:modern_diary/src/features/notes/data/notes_repository.dart';
import 'package:modern_diary/src/features/search/data/search_repository.dart';
import 'package:modern_diary/src/features/secrets/data/secrets_repository.dart';
import 'package:modern_diary/src/features/settings/data/countries_repository.dart';
import 'package:modern_diary/src/features/tags/data/tags_repository.dart';
import 'package:modern_diary/src/features/users/data/users_repository.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _envelope(Object? data, {Map<String, dynamic>? meta}) {
  return {
    'code': 'OK',
    'success': true,
    'data': data,
    'message': null,
    'errors': const [],
    'meta': meta ?? const {},
    'request_id': 'req_teste',
    'timestamp': '2026-10-20T22:00:00Z',
  };
}

http.Response _ok(Object? data, {Map<String, dynamic>? meta}) {
  return http.Response(
    jsonEncode(_envelope(data, meta: meta)),
    200,
    headers: {'content-type': 'application/json'},
  );
}

/// API de teste com a lista de metas vazia, para o conteúdo ficar curto.
MockClient _emptyApi() {
  return MockClient((request) async {
    final path = request.url.path;
    if (path == '/api/v1/auth/me') {
      return _ok({
        'id': 1,
        'username': 'jonathan',
        'role': 'USER',
        'created_at': '2026-10-19T23:00:00Z',
      });
    }
    if (path == '/api/v1/agenda/summary') {
      return _ok(const [], meta: {'from': '2026-01-01', 'to': '2026-12-31'});
    }
    if (path.startsWith('/api/v1/agenda/days/')) {
      return _ok({
        'day': path.split('/').last,
        'notes': const [],
        'activities': const [],
      });
    }
    if (path == '/api/v1/goals') {
      return _ok(
        const [],
        meta: {
          'page': 1,
          'per_page': 12,
          'total': 0,
          'total_pages': 0,
          'counts': {'ACTIVE': 0, 'COMPLETED': 0, 'ARCHIVED': 0},
        },
      );
    }
    return _ok(const <Object>[], meta: {'total': 0});
  });
}

/// API de teste com uma tag usada por um conhecimento, para navegar do menu
/// de tags até o registro.
MockClient _tagNavigationApi({required List<int> detailRequests}) {
  final knowledgeItem = {
    'id': 42,
    'title': 'Índice no banco',
    'content': null,
    'links': const [],
    'relations': const [],
    'goals': const [],
    'tags': [
      {
        'id': 1,
        'name': 'estudo',
        'color': '#22C55E',
        'description': null,
        'usage_count': 1,
      },
    ],
    'attachments': const [],
    'created_at': '2026-10-19T23:00:00Z',
    'updated_at': '2026-10-19T23:00:00Z',
  };

  return MockClient((request) async {
    final path = request.url.path;
    if (path == '/api/v1/auth/me') {
      return _ok({
        'id': 1,
        'username': 'jonathan',
        'role': 'USER',
        'created_at': '2026-10-19T23:00:00Z',
      });
    }
    if (path == '/api/v1/agenda/summary') {
      return _ok(const [], meta: {'from': '2026-01-01', 'to': '2026-12-31'});
    }
    if (path.startsWith('/api/v1/agenda/days/')) {
      return _ok({
        'day': path.split('/').last,
        'notes': const [],
        'activities': const [],
      });
    }
    if (path == '/api/v1/tags') {
      return _ok(
        [
          {
            'id': 1,
            'name': 'estudo',
            'color': '#22C55E',
            'description': null,
            'usage_count': 1,
          },
        ],
        meta: {'page': 1, 'per_page': 20, 'total': 1, 'total_pages': 1},
      );
    }
    if (path == '/api/v1/tags/1/usages') {
      return _ok(
        [
          {
            'target_type': 'KNOWLEDGE',
            'target_id': 42,
            'title': 'Índice no banco',
            'day': null,
          },
        ],
        meta: {'page': 1, 'per_page': 10, 'total': 1, 'total_pages': 1},
      );
    }
    if (path == '/api/v1/knowledge/42') {
      detailRequests.add(42);
      return _ok(knowledgeItem);
    }
    if (path == '/api/v1/knowledge') {
      return _ok(
        [knowledgeItem],
        meta: {'page': 1, 'per_page': 12, 'total': 1, 'total_pages': 1},
      );
    }
    return _ok(const <Object>[], meta: {'total': 0});
  });
}

void main() {
  /// Item do menu orbital: agora só o ícone, o nome vem no tooltip.
  Finder menuIcon(IconData icon) {
    return find.descendant(
      of: find.byType(OrbitalMenu),
      matching: find.byIcon(icon),
    );
  }

  testWidgets('o menu orbital fica preso no rodapé mesmo com conteúdo curto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'modern_diary_access_token': 'token-de-teste',
      'modern_diary_user': jsonEncode({
        'id': 1,
        'username': 'jonathan',
        'role': 'USER',
        'created_at': '2026-10-19T23:00:00Z',
      }),
    });

    final token = AuthToken();
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: _emptyApi(),
      tokenProvider: () => token.value,
    );
    final auth = AuthController(
      repository: AuthRepository(apiClient),
      store: SessionStore(),
      token: token,
    );
    await auth.restoreSession();
    expect(auth.user?.username, 'jonathan');
    expect(auth.user?.role, UserRole.user);

    final toat = ToatController();
    addTearDown(toat.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          auth: auth,
          toat: toat,
          preferences: AppPreferences(),
          usersRepository: UsersRepository(apiClient),
          agendaRepository: AgendaRepository(apiClient),
          holidaysRepository: HolidaysRepository(apiClient),
          goalsRepository: GoalsRepository(apiClient),
          knowledgeRepository: KnowledgeRepository(apiClient),
          lifeRepository: LifeRepository(apiClient),
          notesRepository: NotesRepository(apiClient),
          searchRepository: SearchRepository(apiClient),
          tagsRepository: TagsRepository(apiClient),
          auditRepository: AuditRepository(apiClient),
          secretsRepository: SecretsRepository(apiClient),
          countriesRepository: CountriesRepository(apiClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Abre o menu orbital e troca para a aba de metas vazia.
    await tester.tap(find.bySemanticsLabel(AppStrings.menuLabel));
    await tester.pumpAndSettle();
    await tester.tap(menuIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.goalsEmptyTitle), findsOneWidget);

    final menu = find.byType(OrbitalMenu);
    final bottomBefore = tester.getBottomLeft(menu).dy;
    expect(bottomBefore, closeTo(700 - AppSpacing.md, 1));

    // Rolar a página não move o menu.
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(menu).dy, closeTo(bottomBefore, 1));
  });

  testWidgets('clicar no uso de uma tag leva ao conhecimento', (tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'modern_diary_access_token': 'token-de-teste',
      'modern_diary_user': jsonEncode({
        'id': 1,
        'username': 'jonathan',
        'role': 'USER',
        'created_at': '2026-10-19T23:00:00Z',
      }),
    });

    final detailRequests = <int>[];
    final token = AuthToken();
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: _tagNavigationApi(detailRequests: detailRequests),
      tokenProvider: () => token.value,
    );
    final auth = AuthController(
      repository: AuthRepository(apiClient),
      store: SessionStore(),
      token: token,
    );
    await auth.restoreSession();

    final toat = ToatController();
    addTearDown(toat.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          auth: auth,
          toat: toat,
          preferences: AppPreferences(),
          usersRepository: UsersRepository(apiClient),
          agendaRepository: AgendaRepository(apiClient),
          holidaysRepository: HolidaysRepository(apiClient),
          goalsRepository: GoalsRepository(apiClient),
          knowledgeRepository: KnowledgeRepository(apiClient),
          lifeRepository: LifeRepository(apiClient),
          notesRepository: NotesRepository(apiClient),
          searchRepository: SearchRepository(apiClient),
          tagsRepository: TagsRepository(apiClient),
          auditRepository: AuditRepository(apiClient),
          secretsRepository: SecretsRepository(apiClient),
          countriesRepository: CountriesRepository(apiClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(AppStrings.menuLabel));
    await tester.pumpAndSettle();
    await tester.tap(menuIcon(Icons.sell_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('estudo'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.tagUsageTitle('estudo')), findsOneWidget);

    await tester.tap(find.text('Índice no banco'));
    await tester.pumpAndSettle();

    expect(detailRequests, [42]);
    expect(find.byType(KnowledgeCard), findsOneWidget);
    expect(find.text(AppStrings.knowledgeNoContent), findsOneWidget);
  });

  testWidgets('avatar do header e menu orbital abrem as configurações', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'modern_diary_access_token': 'token-de-teste',
      'modern_diary_user': jsonEncode({
        'id': 1,
        'username': 'jonathan',
        'role': 'USER',
        'created_at': '2026-10-19T23:00:00Z',
      }),
    });

    final token = AuthToken();
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: _emptyApi(),
      tokenProvider: () => token.value,
    );
    final auth = AuthController(
      repository: AuthRepository(apiClient),
      store: SessionStore(),
      token: token,
    );
    await auth.restoreSession();

    final toat = ToatController();
    final preferences = AppPreferences();
    addTearDown(toat.dispose);
    addTearDown(auth.dispose);
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          auth: auth,
          toat: toat,
          preferences: preferences,
          usersRepository: UsersRepository(apiClient),
          agendaRepository: AgendaRepository(apiClient),
          holidaysRepository: HolidaysRepository(apiClient),
          goalsRepository: GoalsRepository(apiClient),
          knowledgeRepository: KnowledgeRepository(apiClient),
          lifeRepository: LifeRepository(apiClient),
          notesRepository: NotesRepository(apiClient),
          searchRepository: SearchRepository(apiClient),
          tagsRepository: TagsRepository(apiClient),
          auditRepository: AuditRepository(apiClient),
          secretsRepository: SecretsRepository(apiClient),
          countriesRepository: CountriesRepository(apiClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // O rodapé mostra quem fez e o contato, configurados em AppInfo.
    expect(
      find.text(AppStrings.footerCreatedBy(AppInfo.authorName)),
      findsOneWidget,
    );
    expect(find.text(AppInfo.authorContact), findsOneWidget);

    // O avatar abre o menu escondido e leva às configurações básicas.
    await tester.tap(find.bySemanticsLabel(AppStrings.profileMenuLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.settingsTitle));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsTitle), findsWidgets);
    expect(find.text(AppStrings.settingsThemeLabel), findsOneWidget);

    await tester.ensureVisible(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    // O mesmo ajuste também está no menu orbital.
    await tester.tap(find.bySemanticsLabel(AppStrings.menuLabel));
    await tester.pumpAndSettle();
    await tester.tap(menuIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsThemeLabel), findsOneWidget);
  });

  testWidgets('clicar no logo volta para o início', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'modern_diary_access_token': 'token-de-teste',
      'modern_diary_user': jsonEncode({
        'id': 1,
        'username': 'jonathan',
        'role': 'USER',
        'created_at': '2026-10-19T23:00:00Z',
      }),
    });

    final token = AuthToken();
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: _emptyApi(),
      tokenProvider: () => token.value,
    );
    final auth = AuthController(
      repository: AuthRepository(apiClient),
      store: SessionStore(),
      token: token,
    );
    await auth.restoreSession();

    final toat = ToatController();
    addTearDown(toat.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          auth: auth,
          toat: toat,
          preferences: AppPreferences(),
          usersRepository: UsersRepository(apiClient),
          agendaRepository: AgendaRepository(apiClient),
          holidaysRepository: HolidaysRepository(apiClient),
          goalsRepository: GoalsRepository(apiClient),
          knowledgeRepository: KnowledgeRepository(apiClient),
          lifeRepository: LifeRepository(apiClient),
          notesRepository: NotesRepository(apiClient),
          searchRepository: SearchRepository(apiClient),
          tagsRepository: TagsRepository(apiClient),
          auditRepository: AuditRepository(apiClient),
          secretsRepository: SecretsRepository(apiClient),
          countriesRepository: CountriesRepository(apiClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel(AppStrings.menuLabel));
    await tester.pumpAndSettle();
    await tester.tap(menuIcon(Icons.flag_outlined));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.goalsEmptyTitle), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(AppStrings.logoHomeTooltip));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.greeting('jonathan')), findsOneWidget);
  });

  testWidgets('o rodapé só aparece depois de rolar a tela', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'modern_diary_access_token': 'token-de-teste',
      'modern_diary_user': jsonEncode({
        'id': 1,
        'username': 'jonathan',
        'role': 'USER',
        'created_at': '2026-10-19T23:00:00Z',
      }),
    });

    final token = AuthToken();
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: _emptyApi(),
      tokenProvider: () => token.value,
    );
    final auth = AuthController(
      repository: AuthRepository(apiClient),
      store: SessionStore(),
      token: token,
    );
    await auth.restoreSession();

    final toat = ToatController();
    addTearDown(toat.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          auth: auth,
          toat: toat,
          preferences: AppPreferences(),
          usersRepository: UsersRepository(apiClient),
          agendaRepository: AgendaRepository(apiClient),
          holidaysRepository: HolidaysRepository(apiClient),
          goalsRepository: GoalsRepository(apiClient),
          knowledgeRepository: KnowledgeRepository(apiClient),
          lifeRepository: LifeRepository(apiClient),
          notesRepository: NotesRepository(apiClient),
          searchRepository: SearchRepository(apiClient),
          tagsRepository: TagsRepository(apiClient),
          auditRepository: AuditRepository(apiClient),
          secretsRepository: SecretsRepository(apiClient),
          countriesRepository: CountriesRepository(apiClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final footer = find.text(AppStrings.footerCreatedBy(AppInfo.authorName));
    expect(footer, findsOneWidget);
    // Fora da área visível: só chega nele rolando.
    expect(tester.getRect(footer).top, greaterThanOrEqualTo(900));

    await tester.scrollUntilVisible(footer, 300);
    await tester.pumpAndSettle();

    expect(tester.getRect(footer).top, lessThan(900));
  });

  testWidgets('a tecla Q abre a pesquisa, mas não enquanto se digita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'modern_diary_access_token': 'token-de-teste',
      'modern_diary_user': jsonEncode({
        'id': 1,
        'username': 'jonathan',
        'role': 'USER',
        'created_at': '2026-10-19T23:00:00Z',
      }),
    });

    final token = AuthToken();
    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: _emptyApi(),
      tokenProvider: () => token.value,
    );
    final auth = AuthController(
      repository: AuthRepository(apiClient),
      store: SessionStore(),
      token: token,
    );
    await auth.restoreSession();

    final toat = ToatController();
    addTearDown(toat.dispose);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: HomeScreen(
          auth: auth,
          toat: toat,
          preferences: AppPreferences(),
          usersRepository: UsersRepository(apiClient),
          agendaRepository: AgendaRepository(apiClient),
          holidaysRepository: HolidaysRepository(apiClient),
          goalsRepository: GoalsRepository(apiClient),
          knowledgeRepository: KnowledgeRepository(apiClient),
          lifeRepository: LifeRepository(apiClient),
          notesRepository: NotesRepository(apiClient),
          searchRepository: SearchRepository(apiClient),
          tagsRepository: TagsRepository(apiClient),
          auditRepository: AuditRepository(apiClient),
          secretsRepository: SecretsRepository(apiClient),
          countriesRepository: CountriesRepository(apiClient),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.searchHint), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.searchClose));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.searchHint), findsNothing);

    // Com o cursor no campo de busca das notas, Q é texto, não atalho.
    await tester.tap(find.bySemanticsLabel(AppStrings.menuLabel));
    await tester.pumpAndSettle();
    await tester.tap(menuIcon(Icons.sticky_note_2_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.searchHint), findsNothing);
  });
}
