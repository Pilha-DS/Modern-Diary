import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';

/// Resultado do botão "Puxar feriados": quantos entraram e de quais anos.
class HolidaySyncResult {
  const HolidaySyncResult({required this.total, required this.years});

  final int total;
  final List<int> years;

  factory HolidaySyncResult.fromMeta(Map<String, dynamic> meta) {
    final rawYears = meta['years'];
    return HolidaySyncResult(
      total: readInt(meta['total']),
      years: rawYears is List
          ? rawYears.whereType<int>().toList()
          : const <int>[],
    );
  }
}

/// Contrato consumido pelos ajustes; permite testar sem HTTP.
abstract interface class HolidaysDataSource {
  Future<HolidaySyncResult> sync(String countryIso2);
}

class HolidaysRepository implements HolidaysDataSource {
  HolidaysRepository(this._client);

  final ApiClient _client;

  @override
  Future<HolidaySyncResult> sync(String countryIso2) async {
    final envelope = await _client.post(
      '/api/v1/holidays/sync',
      body: {'country_iso2': countryIso2},
      parse: (_) {},
    );
    return HolidaySyncResult.fromMeta(envelope.meta);
  }
}
