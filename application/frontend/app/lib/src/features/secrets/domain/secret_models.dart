import '../../../core/domain/sensitivity_level.dart';

/// Permissões de uma credencial em uma área.
class SecretPermission {
  const SecretPermission({
    required this.read,
    this.create = false,
    this.write = false,
  });

  /// Nível máximo que a credencial pode consultar nesta área.
  final SensitivityLevel read;
  final bool create;
  final bool write;

  SecretPermission copyWith({
    SensitivityLevel? read,
    bool? create,
    bool? write,
  }) {
    return SecretPermission(
      read: read ?? this.read,
      create: create ?? this.create,
      write: write ?? this.write,
    );
  }

  factory SecretPermission.fromJson(Map<String, dynamic> json) {
    return SecretPermission(
      read: SensitivityLevel.fromApi(json['read'] as String?),
      create: json['create'] as bool? ?? false,
      write: json['write'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
    'read': read.apiValue,
    'create': create,
    'write': write,
  };
}

/// Credencial de integração, sem o token — ele só existe na criação e na
/// rotação.
class ApiSecret {
  const ApiSecret({
    required this.id,
    required this.name,
    required this.tokenHint,
    required this.isActive,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });

  final int id;
  final String name;

  /// Final do token, para o usuário reconhecer a credencial.
  final String tokenHint;
  final bool isActive;
  final Map<PermissionArea, SecretPermission> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;

  bool get isRevoked => !isActive;

  /// Permissões na ordem das áreas, para exibição estável.
  List<(PermissionArea, SecretPermission)> get orderedPermissions {
    return [
      for (final area in PermissionArea.values)
        if (permissions[area] case final permission?) (area, permission),
    ];
  }

  factory ApiSecret.fromJson(Map<String, dynamic> json) {
    final rawPermissions = json['permissions'];
    final permissions = <PermissionArea, SecretPermission>{};
    if (rawPermissions is Map) {
      for (final entry in rawPermissions.entries) {
        final area = PermissionArea.tryFromApi(entry.key as String?);
        if (area == null || entry.value is! Map) {
          continue;
        }
        permissions[area] = SecretPermission.fromJson(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    return ApiSecret(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      tokenHint: json['token_hint'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      permissions: permissions,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      lastUsedAt: json['last_used_at'] == null
          ? null
          : _parseDate(json['last_used_at']),
    );
  }
}

/// Resultado da criação e da rotação: o token aparece uma única vez.
class SecretCreation {
  const SecretCreation({required this.secret, required this.token});

  final ApiSecret secret;
  final String token;

  factory SecretCreation.fromJson(Map<String, dynamic> json) {
    return SecretCreation(
      secret: ApiSecret.fromJson(json),
      token: json['token'] as String? ?? '',
    );
  }
}

class SecretsPage {
  const SecretsPage({
    required this.secrets,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<ApiSecret> secrets;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

/// Decisão de acesso registrada para uma credencial.
class SecretAuditEntry {
  const SecretAuditEntry({
    required this.id,
    required this.area,
    required this.action,
    required this.result,
    required this.createdAt,
    this.targetType,
    this.targetId,
  });

  final int id;
  final String area;
  final String action;
  final String result;
  final String? targetType;
  final int? targetId;
  final DateTime createdAt;

  bool get isDenied => result == 'DENIED';

  factory SecretAuditEntry.fromJson(Map<String, dynamic> json) {
    return SecretAuditEntry(
      id: json['id'] as int,
      area: json['area'] as String? ?? '',
      action: json['action'] as String? ?? '',
      result: json['result'] as String? ?? '',
      targetType: json['target_type'] as String?,
      targetId: json['target_id'] as int?,
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class SecretAuditPage {
  const SecretAuditPage({
    required this.entries,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<SecretAuditEntry> entries;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

DateTime _parseDate(Object? raw) {
  return DateTime.parse(raw as String? ?? '1970-01-01T00:00:00');
}
