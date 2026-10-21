import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../domain/secret_models.dart';

/// Contrato consumido pelo controller; permite testar sem HTTP.
abstract interface class SecretsDataSource {
  Future<SecretsPage> fetchPage({required int page, int? perPage});

  Future<SecretCreation> createSecret({
    required String name,
    required Map<PermissionArea, SecretPermission> permissions,
  });

  Future<ApiSecret> updateSecret(
    int secretId, {
    String? name,
    Map<PermissionArea, SecretPermission>? permissions,
  });

  Future<SecretCreation> rotateSecret(int secretId);

  Future<ApiSecret> revokeSecret(int secretId);

  Future<SecretAuditPage> fetchAudit(
    int secretId, {
    required int page,
    int? perPage,
  });
}

class SecretsRepository implements SecretsDataSource {
  SecretsRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 10;

  @override
  Future<SecretsPage> fetchPage({required int page, int? perPage}) async {
    final requested = perPage ?? pageSize;
    final envelope = await _client.get(
      '/api/v1/secrets',
      query: {'page': '$page', 'per_page': '$requested'},
      parse: (data) {
        final list = data! as List;
        return list
            .whereType<Map>()
            .map((item) => ApiSecret.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      },
    );
    final meta = envelope.meta;

    return SecretsPage(
      secrets: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: requested),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  @override
  Future<SecretCreation> createSecret({
    required String name,
    required Map<PermissionArea, SecretPermission> permissions,
  }) async {
    final envelope = await _client.post(
      '/api/v1/secrets',
      body: {'name': name, 'permissions': _permissionsBody(permissions)},
      parse: _parseCreation,
    );
    return envelope.data!;
  }

  @override
  Future<ApiSecret> updateSecret(
    int secretId, {
    String? name,
    Map<PermissionArea, SecretPermission>? permissions,
  }) async {
    final body = <String, Object?>{};
    if (name != null) {
      body['name'] = name;
    }
    if (permissions != null) {
      body['permissions'] = _permissionsBody(permissions);
    }

    final envelope = await _client.patch(
      '/api/v1/secrets/$secretId',
      body: body,
      parse: _parseSecret,
    );
    return envelope.data!;
  }

  @override
  Future<SecretCreation> rotateSecret(int secretId) async {
    final envelope = await _client.post(
      '/api/v1/secrets/$secretId/rotate',
      parse: _parseCreation,
    );
    return envelope.data!;
  }

  @override
  Future<ApiSecret> revokeSecret(int secretId) async {
    final envelope = await _client.delete(
      '/api/v1/secrets/$secretId',
      parse: _parseSecret,
    );
    return envelope.data!;
  }

  @override
  Future<SecretAuditPage> fetchAudit(
    int secretId, {
    required int page,
    int? perPage,
  }) async {
    final requested = perPage ?? pageSize;
    final envelope = await _client.get(
      '/api/v1/secrets/$secretId/audit',
      query: {'page': '$page', 'per_page': '$requested'},
      parse: (data) {
        final list = data! as List;
        return list
            .whereType<Map>()
            .map(
              (item) =>
                  SecretAuditEntry.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      },
    );
    final meta = envelope.meta;

    return SecretAuditPage(
      entries: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: requested),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  Map<String, Object?> _permissionsBody(
    Map<PermissionArea, SecretPermission> permissions,
  ) {
    return {
      for (final entry in permissions.entries)
        entry.key.apiValue: entry.value.toJson(),
    };
  }

  ApiSecret _parseSecret(Object? data) {
    return ApiSecret.fromJson(Map<String, dynamic>.from(data! as Map));
  }

  SecretCreation _parseCreation(Object? data) {
    return SecretCreation.fromJson(Map<String, dynamic>.from(data! as Map));
  }
}
