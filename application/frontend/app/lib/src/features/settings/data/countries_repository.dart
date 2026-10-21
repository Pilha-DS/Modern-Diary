import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../domain/country_models.dart';

/// Contrato consumido pelos ajustes para escolher a nacionalidade.
abstract interface class CountriesDataSource {
  Future<CountryPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
  });
}

class CountriesRepository implements CountriesDataSource {
  CountriesRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 12;

  @override
  Future<CountryPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
  }) async {
    final requested = perPage ?? pageSize;
    final cleanedQuery = query?.trim();
    final envelope = await _client.get(
      '/api/v1/countries',
      query: {
        'page': '$page',
        'per_page': '$requested',
        if (cleanedQuery != null && cleanedQuery.isNotEmpty) 'q': cleanedQuery,
      },
      parse: _parseCountries,
    );
    final meta = envelope.meta;

    return CountryPage(
      countries: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: requested),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  List<Country> _parseCountries(Object? data) {
    final list = data! as List;
    return list
        .whereType<Map>()
        .map((item) => Country.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
