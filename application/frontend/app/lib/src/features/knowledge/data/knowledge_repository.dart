import '../../../core/config/api_config.dart';
import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../domain/knowledge_models.dart';

/// Contrato consumido pelo controller; permite testar sem HTTP.
abstract interface class KnowledgeDataSource {
  Future<KnowledgePage> fetchPage({
    required int page,
    int? perPage,
    int? tagId,
  });

  Future<KnowledgeGraphData> fetchGraph({int? tagId});

  Future<KnowledgeItem> fetchItem(int itemId);

  Future<KnowledgeItem> createItem({
    required String title,
    String? content,
    List<KnowledgeExternalLink>? links,
    List<int>? tagIds,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  });

  Future<KnowledgeItem> updateItem(
    int itemId, {
    String? title,
    String? content,
    bool? changeContent,
    List<KnowledgeExternalLink>? links,
    bool? changeLinks,
    List<int>? tagIds,
    bool? changeTags,
    SensitivityLevel? sensitivity,
  });

  Future<void> deleteItem(int itemId);

  Future<void> addRelation(int itemId, int targetId);

  Future<void> removeRelation(int itemId, int targetId);

  Future<void> addGoal(int itemId, int goalId);

  Future<void> removeGoal(int itemId, int goalId);

  Future<KnowledgeAttachment> uploadAttachment(
    int itemId,
    KnowledgeUploadFile file,
  );

  Future<void> deleteAttachment(int itemId, int attachmentId);

  Future<KnowledgeObservation> addObservation(int itemId, String text);

  Future<void> deleteObservation(int itemId, int observationId);

  Uri attachmentDownloadUri(KnowledgeAttachment attachment);
}

class KnowledgeRepository implements KnowledgeDataSource {
  KnowledgeRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 12;

  @override
  Future<KnowledgePage> fetchPage({
    required int page,
    int? perPage,
    int? tagId,
  }) async {
    final requested = perPage ?? pageSize;
    final envelope = await _client.get(
      '/api/v1/knowledge',
      query: {
        'page': '$page',
        'per_page': '$requested',
        if (tagId != null) 'tag_id': '$tagId',
      },
      parse: (data) => _parseItems(data),
    );
    final meta = envelope.meta;

    return KnowledgePage(
      items: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: requested),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  @override
  Future<KnowledgeGraphData> fetchGraph({int? tagId}) async {
    final envelope = await _client.get(
      '/api/v1/knowledge/graph',
      query: {if (tagId != null) 'tag_id': '$tagId'},
      parse: (data) {
        final map = Map<String, dynamic>.from(data! as Map);
        return (
          nodes: _parseNodes(map['nodes']),
          edges: _parseEdges(map['edges']),
        );
      },
    );
    final data = envelope.data!;

    return KnowledgeGraphData(
      nodes: data.nodes,
      edges: data.edges,
      total: readInt(envelope.meta['total'], fallback: data.nodes.length),
      truncated: envelope.meta['truncated'] as bool? ?? false,
    );
  }

  @override
  Future<KnowledgeItem> fetchItem(int itemId) async {
    final envelope = await _client.get(
      '/api/v1/knowledge/$itemId',
      parse: _parseItem,
    );
    return envelope.data!;
  }

  @override
  Future<KnowledgeItem> createItem({
    required String title,
    String? content,
    List<KnowledgeExternalLink>? links,
    List<int>? tagIds,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    final envelope = await _client.post(
      '/api/v1/knowledge',
      body: {
        'title': title,
        'content': content,
        'links': [for (final link in links ?? const []) link.toJson()],
        'tag_ids': tagIds ?? const <int>[],
        'sensitivity': sensitivity.apiValue,
      },
      parse: _parseItem,
    );
    return envelope.data!;
  }

  @override
  Future<KnowledgeItem> updateItem(
    int itemId, {
    String? title,
    String? content,
    bool? changeContent,
    List<KnowledgeExternalLink>? links,
    bool? changeLinks,
    List<int>? tagIds,
    bool? changeTags,
    SensitivityLevel? sensitivity,
  }) async {
    final body = <String, Object?>{};
    if (title != null) {
      body['title'] = title;
    }
    if (changeContent ?? false) {
      body['content'] = content;
    }
    if (changeLinks ?? false) {
      body['links'] = [for (final link in links ?? const []) link.toJson()];
    }
    if (changeTags ?? false) {
      body['tag_ids'] = tagIds ?? const <int>[];
    }
    if (sensitivity != null) {
      body['sensitivity'] = sensitivity.apiValue;
    }

    final envelope = await _client.patch(
      '/api/v1/knowledge/$itemId',
      body: body,
      parse: _parseItem,
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteItem(int itemId) async {
    await _client.delete('/api/v1/knowledge/$itemId', parse: (_) {});
  }

  @override
  Future<void> addRelation(int itemId, int targetId) async {
    await _client.post(
      '/api/v1/knowledge/$itemId/relations',
      body: {'target_id': targetId},
      parse: (_) {},
    );
  }

  @override
  Future<void> removeRelation(int itemId, int targetId) async {
    await _client.delete(
      '/api/v1/knowledge/$itemId/relations/$targetId',
      parse: (_) {},
    );
  }

  @override
  Future<void> addGoal(int itemId, int goalId) async {
    await _client.post(
      '/api/v1/knowledge/$itemId/goals',
      body: {'goal_id': goalId},
      parse: (_) {},
    );
  }

  @override
  Future<void> removeGoal(int itemId, int goalId) async {
    await _client.delete(
      '/api/v1/knowledge/$itemId/goals/$goalId',
      parse: (_) {},
    );
  }

  @override
  Future<KnowledgeAttachment> uploadAttachment(
    int itemId,
    KnowledgeUploadFile file,
  ) async {
    final envelope = await _client.upload(
      '/api/v1/knowledge/$itemId/attachments',
      filename: file.filename,
      bytes: file.bytes,
      contentType: file.contentType,
      parse: (data) =>
          KnowledgeAttachment.fromJson(Map<String, dynamic>.from(data! as Map)),
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteAttachment(int itemId, int attachmentId) async {
    await _client.delete(
      '/api/v1/knowledge/$itemId/attachments/$attachmentId',
      parse: (_) {},
    );
  }

  @override
  Future<KnowledgeObservation> addObservation(int itemId, String text) async {
    final envelope = await _client.post(
      '/api/v1/knowledge/$itemId/observations',
      body: {'text': text},
      parse: (data) => KnowledgeObservation.fromJson(
        Map<String, dynamic>.from(data! as Map),
      ),
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteObservation(int itemId, int observationId) async {
    await _client.delete(
      '/api/v1/knowledge/$itemId/observations/$observationId',
      parse: (_) {},
    );
  }

  @override
  Uri attachmentDownloadUri(KnowledgeAttachment attachment) {
    final base = ApiConfig.baseUrl;
    final raw = attachment.downloadUrl;
    final resolved = base.isEmpty ? raw : '$base$raw';
    final uri = Uri.parse(resolved);
    return uri.hasScheme ? uri : Uri.base.resolveUri(uri);
  }

  KnowledgeItem _parseItem(Object? data) {
    return KnowledgeItem.fromJson(Map<String, dynamic>.from(data! as Map));
  }

  List<KnowledgeItem> _parseItems(Object? data) {
    final list = data! as List;
    return list
        .whereType<Map>()
        .map((item) => KnowledgeItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<KnowledgeNodeData> _parseNodes(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) => KnowledgeNodeData.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  List<KnowledgeEdge> _parseEdges(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return raw
        .whereType<Map>()
        .map((item) => KnowledgeEdge.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
