import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../domain/audit_models.dart';

/// Contrato consumido pelo controller; permite testar sem HTTP.
abstract interface class AuditDataSource {
  Future<List<AuditDaySummary>> fetchDays({
    required DateTime from,
    required DateTime to,
  });

  Future<AuditEventPage> fetchDay(
    DateTime day, {
    required int page,
    int? perPage,
  });

  Future<AuditGraphData> fetchGraph(DateTime day);
}

class AuditRepository implements AuditDataSource {
  AuditRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 20;

  @override
  Future<List<AuditDaySummary>> fetchDays({
    required DateTime from,
    required DateTime to,
  }) async {
    final envelope = await _client.get(
      '/api/v1/audit/days',
      query: {'from': _isoDate(from), 'to': _isoDate(to)},
      parse: (data) {
        if (data is! List) {
          return const <AuditDaySummary>[];
        }
        return data
            .whereType<Map>()
            .map(
              (item) =>
                  AuditDaySummary.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      },
    );
    return envelope.data ?? const [];
  }

  @override
  Future<AuditEventPage> fetchDay(
    DateTime day, {
    required int page,
    int? perPage,
  }) async {
    final requested = perPage ?? pageSize;
    final envelope = await _client.get(
      '/api/v1/audit/days/${_isoDate(day)}',
      query: {'page': '$page', 'per_page': '$requested'},
      parse: (data) {
        if (data is! List) {
          return const <AuditEvent>[];
        }
        return data
            .whereType<Map>()
            .map((item) => AuditEvent.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      },
    );
    final meta = envelope.meta;

    return AuditEventPage(
      items: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: requested),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  @override
  Future<AuditGraphData> fetchGraph(DateTime day) async {
    final envelope = await _client.get(
      '/api/v1/audit/days/${_isoDate(day)}/graph',
      parse: (data) {
        final map = Map<String, dynamic>.from(data! as Map);
        return AuditGraphData(
          nodes: _parseList(map['nodes'], AuditGraphNode.fromJson),
          edges: _parseList(map['edges'], AuditGraphEdge.fromJson),
          totalEvents: readInt(map['total_events']),
          truncated: map['truncated'] as bool? ?? false,
        );
      },
    );
    return envelope.data!;
  }

  List<T> _parseList<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) {
      return <T>[];
    }
    return raw
        .whereType<Map>()
        .map((item) => parse(Map<String, dynamic>.from(item)))
        .toList();
  }

  String _isoDate(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }
}
