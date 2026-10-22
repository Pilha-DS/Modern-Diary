import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modern_diary/src/core/network/api_client.dart';
import 'package:modern_diary/src/core/network/auth_token.dart';
import 'package:modern_diary/src/core/preferences/app_preferences.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/agenda/data/agenda_repository.dart';
import 'package:modern_diary/src/features/agenda/data/holidays_repository.dart';
import 'package:modern_diary/src/features/audit/data/audit_repository.dart';
import 'package:modern_diary/src/features/auth/data/auth_repository.dart';
import 'package:modern_diary/src/features/auth/data/session_store.dart';
import 'package:modern_diary/src/features/auth/presentation/auth_controller.dart';
import 'package:modern_diary/src/features/goals/data/goals_repository.dart';
import 'package:modern_diary/src/features/home/presentation/home_screen.dart';
import 'package:modern_diary/src/features/knowledge/data/knowledge_repository.dart';
import 'package:modern_diary/src/features/life/data/life_repository.dart';
import 'package:modern_diary/src/features/notes/data/notes_repository.dart';
import 'package:modern_diary/src/features/search/data/search_repository.dart';
import 'package:modern_diary/src/features/secrets/data/secrets_repository.dart';
import 'package:modern_diary/src/features/settings/data/countries_repository.dart';
import 'package:modern_diary/src/features/tags/data/tags_repository.dart';
import 'package:modern_diary/src/features/users/data/users_repository.dart';
import 'package:atena_ui/atena_ui.dart';
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
    return _ok(const <Object>[], meta: {'total': 0});
  });
}

void main() {
  testWidgets('o dia do início abre em modal sem trocar de tela', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
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

    expect(find.text(AppStrings.dashboardDayHint), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    // O painel do dia abre por cima do início, em leitura; as ações aparecem
    // depois de tocar em Editar.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text(AppStrings.activitiesTitle), findsWidgets);
    expect(find.text(AppStrings.noteTitle), findsWidgets);
    await tester.tap(find.text(AppStrings.editDay));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.newActivity), findsOneWidget);

    // A tela por baixo continua sendo o início, não o calendário.
    expect(find.text(AppStrings.quickAccessTitle), findsOneWidget);
    expect(find.text(AppStrings.dashboardDayHint), findsOneWidget);
  });
}
