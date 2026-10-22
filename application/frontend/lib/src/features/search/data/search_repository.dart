import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../domain/search_models.dart';

/// Contrato consumido pelo modal de pesquisa; permite testar sem HTTP.
abstract interface class SearchDataSource {
  Future<SearchPage> search({
    required String query,
    required int page,
    List<SearchType> types = const [],
    DateTime? from,
    DateTime? to,
    int? tagId,
    String? sensitivity,
    int perPage,
  });
}

class SearchRepository implements SearchDataSource {
  SearchRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 20;

  @override
  Future<SearchPage> search({
    required String query,
    required int page,
    List<SearchType> types = const [],
    DateTime? from,
    DateTime? to,
    int? tagId,
    String? sensitivity,
    int perPage = pageSize,
  }) async {
    final envelope = await _client.get(
      '/api/v1/search',
      query: {
        'q': query,
        'page': '$page',
        'per_page': '$perPage',
        if (types.isNotEmpty)
          'types': types.map((type) => type.apiValue).join(','),
        if (from != null) 'from': _date(from),
        if (to != null) 'to': _date(to),
        if (tagId != null) 'tag_id': '$tagId',
        'sensitivity': ?sensitivity,
      },
      parse: (data) {
        final list = data is List ? data : const [];
        return list
            .whereType<Map>()
            .map(
              (item) => SearchResult.fromJson(Map<String, dynamic>.from(item)),
            )
            .whereType<SearchResult>()
            .toList();
      },
    );
    final meta = envelope.meta;

    return SearchPage(
      results: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  String _date(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }
}
