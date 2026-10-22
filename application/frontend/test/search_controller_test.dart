import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/features/search/domain/search_models.dart';
import 'package:modern_diary/src/features/search/presentation/search_controller.dart';

import 'support/fake_search_data_source.dart';

void main() {
  test('sem termo não consulta o back e limpa o resultado', () async {
    final dataSource = FakeSearchDataSource();
    final controller = UniversalSearchController(dataSource);
    addTearDown(controller.dispose);

    await controller.setQuery('orvalho');
    dataSource.page = const SearchPage();
    await controller.setQuery('   ');

    expect(dataSource.requests, hasLength(1));
    expect(controller.hasQuery, isFalse);
    expect(controller.results, isEmpty);
    expect(controller.isLoading, isFalse);
  });

  test('envia termo, filtros e recebe a paginação do back', () async {
    final dataSource = FakeSearchDataSource(
      page: SearchPage(
        results: [searchResult(title: 'Orvalho')],
        page: 1,
        total: 1,
        totalPages: 1,
      ),
    );
    final controller = UniversalSearchController(dataSource);
    addTearDown(controller.dispose);

    await controller.setQuery('orvalho');
    await controller.toggleType(SearchType.knowledge);
    await controller.setPeriod(
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 3, 31),
    );
    await controller.setTag(7);
    await controller.setSensitivity('publico');

    final last = dataSource.requests.last;
    expect(last.query, 'orvalho');
    expect(last.types, [SearchType.knowledge]);
    expect(last.from, DateTime(2026, 3, 1));
    expect(last.to, DateTime(2026, 3, 31));
    expect(last.tagId, 7);
    expect(last.sensitivity, 'publico');
    expect(controller.results.single.title, 'Orvalho');
    expect(controller.total, 1);
  });

  test('carrega a próxima página sob demanda e para no fim', () async {
    final firstPage = SearchPage(
      results: [searchResult(ref: '1')],
      page: 1,
      total: 2,
      totalPages: 2,
    );
    final dataSource = FakeSearchDataSource(page: firstPage);
    final controller = UniversalSearchController(dataSource);
    addTearDown(controller.dispose);

    await controller.setQuery('orvalho');
    expect(controller.hasMore, isTrue);

    dataSource.page = SearchPage(
      results: [searchResult(ref: '2')],
      page: 2,
      total: 2,
      totalPages: 2,
    );
    await controller.loadMore();

    expect(controller.results.map((result) => result.ref), ['1', '2']);
    expect(controller.hasMore, isFalse);

    await controller.loadMore();
    expect(dataSource.requests, hasLength(2));
  });

  test('falha da busca vira erro com mensagem para a tela', () async {
    final dataSource = FakeSearchDataSource()
      ..error = const ApiException(
        code: 'SEARCH_FAILED',
        message: 'Não foi possível pesquisar agora.',
      );
    final controller = UniversalSearchController(dataSource);
    addTearDown(controller.dispose);

    await controller.setQuery('orvalho');

    expect(controller.error?.message, 'Não foi possível pesquisar agora.');
    expect(controller.results, isEmpty);
    expect(controller.isLoading, isFalse);
  });
}
