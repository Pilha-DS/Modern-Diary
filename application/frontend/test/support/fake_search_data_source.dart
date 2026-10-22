import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/features/search/data/search_repository.dart';
import 'package:modern_diary/src/features/search/domain/search_models.dart';

/// Pedido recebido pela fonte falsa, para conferir o que foi enviado ao back.
class SearchRequest {
  const SearchRequest({
    required this.query,
    required this.page,
    required this.types,
    required this.from,
    required this.to,
    required this.tagId,
    required this.sensitivity,
  });

  final String query;
  final int page;
  final List<SearchType> types;
  final DateTime? from;
  final DateTime? to;
  final int? tagId;
  final String? sensitivity;
}

/// Fonte da pesquisa sem HTTP, com os pedidos guardados para conferência.
class FakeSearchDataSource implements SearchDataSource {
  FakeSearchDataSource({this.page = const SearchPage()});

  SearchPage page;
  ApiException? error;
  final List<SearchRequest> requests = [];

  @override
  Future<SearchPage> search({
    required String query,
    required int page,
    List<SearchType> types = const [],
    DateTime? from,
    DateTime? to,
    int? tagId,
    String? sensitivity,
    int perPage = 20,
  }) async {
    requests.add(
      SearchRequest(
        query: query,
        page: page,
        types: types,
        from: from,
        to: to,
        tagId: tagId,
        sensitivity: sensitivity,
      ),
    );
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return this.page;
  }
}

SearchResult searchResult({
  SearchType type = SearchType.knowledge,
  String ref = '1',
  String? title,
  String? snippet,
  DateTime? day,
  String sensitivity = 'publico',
}) {
  return SearchResult(
    type: type,
    ref: ref,
    title: title,
    snippet: snippet,
    day: day,
    sensitivity: sensitivity,
    updatedAt: DateTime(2026, 10, 20),
  );
}
