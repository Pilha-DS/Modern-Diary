import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/home/presentation/home_navigation.dart';
import 'package:modern_diary/src/features/search/domain/search_models.dart';
import 'package:modern_diary/src/features/search/presentation/search_dialog.dart';
import 'package:modern_diary/src/features/tags/data/tags_repository.dart';
import 'package:modern_diary/src/features/tags/domain/tag_models.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_search_data_source.dart';

class _EmptyTags implements TagsDataSource {
  @override
  Future<TagPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
  }) async {
    return const TagPage(
      tags: [],
      page: 1,
      perPage: 20,
      total: 0,
      totalPages: 0,
    );
  }

  @override
  Future<Tag> createTag({
    required String name,
    required String colorHex,
    String? description,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteTag(int tagId) => throw UnimplementedError();

  @override
  Future<TagUsagePage> fetchUsages(
    int tagId, {
    required int page,
    int? perPage,
  }) => throw UnimplementedError();

  @override
  Future<Tag> updateTag(
    int tagId, {
    String? name,
    String? colorHex,
    String? description,
    bool? changeDescription,
  }) => throw UnimplementedError();
}

void main() {
  late List<int> openedKnowledge;
  late List<int> openedGoals;
  late List<int> openedNotes;
  late List<DateTime> openedDays;

  setUp(() {
    openedKnowledge = [];
    openedGoals = [];
    openedNotes = [];
    openedDays = [];
  });

  HomeNavigation navigation() {
    return HomeNavigation(
      openTag: (_) {},
      openGoal: openedGoals.add,
      openKnowledgeItem: openedKnowledge.add,
      openNote: openedNotes.add,
      openDay: openedDays.add,
      openSection: (_) {},
    );
  }

  Future<void> openDialog(
    WidgetTester tester,
    FakeSearchDataSource dataSource,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => AppButton(
              label: 'abrir',
              onPressed: () => showSearchDialog(
                context,
                dataSource: dataSource,
                tagsDataSource: _EmptyTags(),
                navigation: navigation(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('busca com debounce e mostra o resultado', (tester) async {
    final dataSource = FakeSearchDataSource(
      page: SearchPage(
        results: [
          searchResult(ref: '42', title: 'Orvalho no campo', snippet: 'texto'),
        ],
        page: 1,
        total: 1,
        totalPages: 1,
      ),
    );
    await openDialog(tester, dataSource);

    expect(find.text(AppStrings.searchStartTitle), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'orvalho');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(dataSource.requests, hasLength(1));
    expect(dataSource.requests.single.query, 'orvalho');
    expect(find.text('Orvalho no campo'), findsOneWidget);
    expect(find.text(AppStrings.searchTotal(1)), findsOneWidget);
  });

  testWidgets('o filtro de tipo vai para o back e pode ser limpo', (
    tester,
  ) async {
    final dataSource = FakeSearchDataSource();
    await openDialog(tester, dataSource);

    await tester.enterText(find.byType(TextField), 'orvalho');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppChip),
        matching: find.text(AppStrings.auditEntityType('goal')),
      ),
    );
    await tester.pumpAndSettle();
    expect(dataSource.requests.last.types, [SearchType.goal]);

    await tester.tap(
      find.descendant(
        of: find.byType(AppChip),
        matching: find.text(AppStrings.searchAllTypes),
      ),
    );
    await tester.pumpAndSettle();
    expect(dataSource.requests.last.types, isEmpty);
  });

  testWidgets('falha da busca mostra erro com ação de tentar de novo', (
    tester,
  ) async {
    final dataSource = FakeSearchDataSource()
      ..error = const ApiException(
        code: 'SEARCH_FAILED',
        message: 'Não foi possível pesquisar agora.',
      );
    await openDialog(tester, dataSource);

    await tester.enterText(find.byType(TextField), 'orvalho');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.searchErrorTitle), findsOneWidget);
    expect(find.text('Não foi possível pesquisar agora.'), findsOneWidget);
    expect(find.text(AppStrings.searchRetry), findsOneWidget);
  });

  testWidgets('tocar no resultado fecha o modal e abre o registro', (
    tester,
  ) async {
    final dataSource = FakeSearchDataSource(
      page: SearchPage(
        results: [
          searchResult(ref: '42', title: 'Orvalho no campo'),
          searchResult(
            ref: '9',
            type: SearchType.agendaNote,
            snippet: 'diário de hoje',
            day: DateTime(2026, 3, 10),
          ),
        ],
        page: 1,
        total: 2,
        totalPages: 1,
      ),
    );
    await openDialog(tester, dataSource);

    await tester.enterText(find.byType(TextField), 'orvalho');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Orvalho no campo'));
    await tester.pumpAndSettle();

    expect(openedKnowledge, [42]);
    expect(find.text(AppStrings.searchHint), findsNothing);

    // O segundo resultado é uma nota do diário: abre o dia.
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'orvalho');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('diário de hoje'));
    await tester.pumpAndSettle();

    expect(openedDays, [DateTime(2026, 3, 10)]);
  });

  testWidgets('limpar o termo volta ao estado inicial', (tester) async {
    final dataSource = FakeSearchDataSource(
      page: SearchPage(
        results: [searchResult(title: 'Orvalho')],
        total: 1,
        totalPages: 1,
      ),
    );
    await openDialog(tester, dataSource);

    await tester.enterText(find.byType(TextField), 'orvalho');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Orvalho'), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.searchClear));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.searchStartTitle), findsOneWidget);
    expect(dataSource.requests, hasLength(1));
  });
}
