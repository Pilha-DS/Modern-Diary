import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../domain/tag_models.dart';

/// Contrato consumido pela seção, pelo seletor e pelos formulários.
abstract interface class TagsDataSource {
  Future<TagPage> fetchPage({required int page, int? perPage, String? query});

  Future<Tag> createTag({
    required String name,
    required String colorHex,
    String? description,
  });

  Future<Tag> updateTag(
    int tagId, {
    String? name,
    String? colorHex,
    String? description,
    bool? changeDescription,
  });

  Future<void> deleteTag(int tagId);

  Future<TagUsagePage> fetchUsages(
    int tagId, {
    required int page,
    int? perPage,
  });
}

class TagsRepository implements TagsDataSource {
  TagsRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 20;

  @override
  Future<TagPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
  }) async {
    final requested = perPage ?? pageSize;
    final cleanedQuery = query?.trim();
    final envelope = await _client.get(
      '/api/v1/tags',
      query: {
        'page': '$page',
        'per_page': '$requested',
        if (cleanedQuery != null && cleanedQuery.isNotEmpty) 'q': cleanedQuery,
      },
      parse: _parseTags,
    );
    final meta = envelope.meta;

    return TagPage(
      tags: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: requested),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  @override
  Future<Tag> createTag({
    required String name,
    required String colorHex,
    String? description,
  }) async {
    final envelope = await _client.post(
      '/api/v1/tags',
      body: {'name': name, 'color': colorHex, 'description': description},
      parse: _parseTag,
    );
    return envelope.data!;
  }

  @override
  Future<Tag> updateTag(
    int tagId, {
    String? name,
    String? colorHex,
    String? description,
    bool? changeDescription,
  }) async {
    final body = <String, Object?>{};
    if (name != null) {
      body['name'] = name;
    }
    if (colorHex != null) {
      body['color'] = colorHex;
    }
    if (changeDescription ?? false) {
      body['description'] = description;
    }

    final envelope = await _client.patch(
      '/api/v1/tags/$tagId',
      body: body,
      parse: _parseTag,
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteTag(int tagId) async {
    await _client.delete('/api/v1/tags/$tagId', parse: (_) {});
  }

  @override
  Future<TagUsagePage> fetchUsages(
    int tagId, {
    required int page,
    int? perPage,
  }) async {
    final requested = perPage ?? pageSize;
    final envelope = await _client.get(
      '/api/v1/tags/$tagId/usages',
      query: {'page': '$page', 'per_page': '$requested'},
      parse: (data) {
        final list = data! as List;
        return list
            .whereType<Map>()
            .map((item) => TagUsage.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      },
    );
    final meta = envelope.meta;

    return TagUsagePage(
      usages: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  Tag _parseTag(Object? data) {
    return Tag.fromJson(Map<String, dynamic>.from(data! as Map));
  }

  List<Tag> _parseTags(Object? data) {
    final list = data! as List;
    return list
        .whereType<Map>()
        .map((item) => Tag.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
