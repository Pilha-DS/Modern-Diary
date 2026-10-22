import '../../../core/network/api_client.dart';
import '../domain/life_models.dart';

/// Contrato consumido pelo controller; permite testar sem HTTP.
abstract interface class LifeDataSource {
  Future<LifeGraphData> fetchGraph({List<LifeEntityType> types = const []});

  Future<void> link(LifeGraphNode source, LifeGraphNode target);

  Future<void> unlink(LifeGraphNode source, LifeGraphNode target);
}

class LifeRepository implements LifeDataSource {
  LifeRepository(this._client);

  final ApiClient _client;

  @override
  Future<LifeGraphData> fetchGraph({
    List<LifeEntityType> types = const [],
  }) async {
    final envelope = await _client.get(
      '/api/v1/life/graph',
      query: types.isEmpty
          ? null
          : {'types': types.map((type) => type.apiValue).join(',')},
      parse: (data) {
        final map = Map<String, dynamic>.from(data! as Map);
        return LifeGraphData(
          nodes: _parseList(map['nodes'], LifeGraphNode.fromJson),
          edges: _parseList(map['edges'], LifeGraphEdge.fromJson),
          truncated: map['truncated'] as bool? ?? false,
        );
      },
    );
    return envelope.data ?? const LifeGraphData();
  }

  @override
  Future<void> link(LifeGraphNode source, LifeGraphNode target) async {
    await _client.post<void>(
      '/api/v1/life/links',
      body: _body(source, target),
      parse: (_) {},
    );
  }

  @override
  Future<void> unlink(LifeGraphNode source, LifeGraphNode target) async {
    await _client.delete<void>(
      '/api/v1/life/links',
      body: _body(source, target),
      parse: (_) {},
    );
  }

  Map<String, Object?> _body(LifeGraphNode source, LifeGraphNode target) {
    return {
      'source_type': source.type.apiValue,
      'source_ref': source.ref,
      'target_type': target.type.apiValue,
      'target_ref': target.ref,
    };
  }

  List<T> _parseList<T>(Object? raw, T? Function(Map<String, dynamic>) parse) {
    if (raw is! List) {
      return <T>[];
    }
    return raw
        .whereType<Map>()
        .map((item) => parse(Map<String, dynamic>.from(item)))
        .whereType<T>()
        .toList();
  }
}
