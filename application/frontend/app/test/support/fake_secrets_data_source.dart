import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/features/secrets/data/secrets_repository.dart';
import 'package:modern_diary/src/features/secrets/domain/secret_models.dart';

/// Implementação em memória com a mesma regra do back, para testar sem HTTP.
class FakeSecretsDataSource implements SecretsDataSource {
  FakeSecretsDataSource({List<ApiSecret> initial = const []}) {
    _secrets.addAll(initial);
  }

  final List<ApiSecret> _secrets = [];
  final List<SecretAuditEntry> audit = [];
  int _nextId = 1;
  int createCalls = 0;
  int rotateCalls = 0;
  int revokeCalls = 0;

  List<ApiSecret> get secrets => List.unmodifiable(_secrets);

  @override
  Future<SecretsPage> fetchPage({required int page, int? perPage}) async {
    final size = perPage ?? 10;
    final offset = (page - 1) * size;

    return SecretsPage(
      secrets: _secrets.skip(offset).take(size).toList(),
      page: page,
      perPage: size,
      total: _secrets.length,
      totalPages: (_secrets.length / size).ceil(),
    );
  }

  @override
  Future<SecretCreation> createSecret({
    required String name,
    required Map<PermissionArea, SecretPermission> permissions,
  }) async {
    createCalls++;
    final secret = ApiSecret(
      id: _nextId++,
      name: name,
      tokenHint: 'abc123',
      isActive: true,
      permissions: Map.of(permissions),
      createdAt: DateTime(2026, 10, 21),
      updatedAt: DateTime(2026, 10, 21),
    );
    _secrets.insert(0, secret);
    return SecretCreation(secret: secret, token: 'mds_token_$name');
  }

  @override
  Future<ApiSecret> updateSecret(
    int secretId, {
    String? name,
    Map<PermissionArea, SecretPermission>? permissions,
  }) async {
    final current = _find(secretId);
    final updated = _copy(
      current,
      name: name,
      permissions: permissions,
      updatedAt: DateTime(2026, 10, 21, 12),
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<SecretCreation> rotateSecret(int secretId) async {
    rotateCalls++;
    final updated = _copy(
      _find(secretId),
      tokenHint: 'zzz999',
      updatedAt: DateTime(2026, 10, 21, 12),
    );
    _replace(updated);
    return SecretCreation(secret: updated, token: 'mds_novo_$secretId');
  }

  @override
  Future<ApiSecret> revokeSecret(int secretId) async {
    revokeCalls++;
    final updated = _copy(
      _find(secretId),
      isActive: false,
      updatedAt: DateTime(2026, 10, 21, 12),
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<SecretAuditPage> fetchAudit(
    int secretId, {
    required int page,
    int? perPage,
  }) async {
    final size = perPage ?? 10;
    final offset = (page - 1) * size;

    return SecretAuditPage(
      entries: audit.skip(offset).take(size).toList(),
      page: page,
      perPage: size,
      total: audit.length,
      totalPages: (audit.length / size).ceil(),
    );
  }

  ApiSecret _find(int secretId) {
    return _secrets.firstWhere((secret) => secret.id == secretId);
  }

  ApiSecret _copy(
    ApiSecret current, {
    String? name,
    String? tokenHint,
    bool? isActive,
    Map<PermissionArea, SecretPermission>? permissions,
    DateTime? updatedAt,
  }) {
    return ApiSecret(
      id: current.id,
      name: name ?? current.name,
      tokenHint: tokenHint ?? current.tokenHint,
      isActive: isActive ?? current.isActive,
      permissions: permissions == null
          ? current.permissions
          : Map.of(permissions),
      createdAt: current.createdAt,
      updatedAt: updatedAt ?? current.updatedAt,
      lastUsedAt: current.lastUsedAt,
    );
  }

  void _replace(ApiSecret secret) {
    final index = _secrets.indexWhere((item) => item.id == secret.id);
    _secrets[index] = secret;
  }
}
