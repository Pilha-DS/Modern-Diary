import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/core/network/api_client.dart';
import 'package:modern_diary/src/features/secrets/data/secrets_repository.dart';
import 'package:modern_diary/src/features/secrets/domain/secret_models.dart';

Map<String, Object?> _secretJson({
  int id = 1,
  String name = 'integracao_externa',
  bool isActive = true,
  Map<String, Object?> permissions = const {
    'conhecimentos': {'read': 'complexo', 'create': true, 'write': true},
    'metas': {'read': 'basico', 'create': false, 'write': false},
  },
}) {
  return {
    'id': id,
    'name': name,
    'token_hint': 'abc123',
    'is_active': isActive,
    'permissions': permissions,
    'created_at': '2026-10-21T10:00:00Z',
    'updated_at': '2026-10-21T10:00:00Z',
    'last_used_at': null,
  };
}

Map<String, Object?> _envelope(
  Object? data, {
  Map<String, Object?> meta = const {},
}) {
  return {
    'code': 'OK',
    'success': true,
    'data': data,
    'message': null,
    'errors': const [],
    'meta': meta,
    'request_id': 'req_teste',
    'timestamp': '2026-10-21T10:00:00Z',
  };
}

SecretsRepository _repository(
  Future<http.Response> Function(http.Request request) handler,
) {
  return SecretsRepository(
    ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: MockClient(handler),
    ),
  );
}

http.Response _json(Object? body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  test('lê credenciais com permissões por área e paginação do meta', () async {
    late http.Request captured;
    final repository = _repository((request) async {
      captured = request;
      return _json(
        _envelope(
          [_secretJson()],
          meta: {'page': 1, 'per_page': 10, 'total': 1, 'total_pages': 1},
        ),
      );
    });

    final page = await repository.fetchPage(page: 1);

    expect(captured.url.path, '/api/v1/secrets');
    expect(captured.url.queryParameters, {'page': '1', 'per_page': '10'});

    final secret = page.secrets.single;
    expect(secret.name, 'integracao_externa');
    expect(secret.tokenHint, 'abc123');
    expect(secret.isActive, isTrue);
    expect(
      secret.permissions[PermissionArea.conhecimentos]?.read,
      SensitivityLevel.complexo,
    );
    expect(secret.permissions[PermissionArea.conhecimentos]?.create, isTrue);
    expect(secret.permissions[PermissionArea.metas]?.write, isFalse);
    expect(secret.permissions.containsKey(PermissionArea.dias), isFalse);
    expect(page.total, 1);
    expect(page.totalPages, 1);
  });

  test(
    'envia nome e permissões na criação e devolve o token uma vez',
    () async {
      late http.Request captured;
      final repository = _repository((request) async {
        captured = request;
        return _json(
          _envelope({..._secretJson(), 'token': 'mds_segredo_completo'}),
        );
      });

      final creation = await repository.createSecret(
        name: 'integracao_externa',
        permissions: {
          PermissionArea.dias: const SecretPermission(
            read: SensitivityLevel.all,
            create: true,
          ),
        },
      );

      expect(captured.method, 'POST');
      expect(captured.url.path, '/api/v1/secrets');
      expect(jsonDecode(captured.body), {
        'name': 'integracao_externa',
        'permissions': {
          'dias': {'read': 'all', 'create': true, 'write': false},
        },
      });
      expect(creation.token, 'mds_segredo_completo');
      expect(creation.secret.name, 'integracao_externa');
    },
  );

  test('envia só os campos informados na atualização', () async {
    late http.Request captured;
    final repository = _repository((request) async {
      captured = request;
      return _json(_envelope(_secretJson(name: 'renomeada')));
    });

    final updated = await repository.updateSecret(7, name: 'renomeada');

    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/v1/secrets/7');
    expect(jsonDecode(captured.body), {'name': 'renomeada'});
    expect(updated.name, 'renomeada');
  });

  test('rotação devolve o novo token', () async {
    late http.Request captured;
    final repository = _repository((request) async {
      captured = request;
      return _json(
        _envelope({
          ..._secretJson(),
          'token_hint': 'novo99',
          'token': 'mds_token_renovado',
        }),
      );
    });

    final creation = await repository.rotateSecret(3);

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/secrets/3/rotate');
    expect(creation.token, 'mds_token_renovado');
    expect(creation.secret.tokenHint, 'novo99');
  });

  test('revogação devolve a credencial inativa', () async {
    late http.Request captured;
    final repository = _repository((request) async {
      captured = request;
      return _json(_envelope(_secretJson(isActive: false)));
    });

    final secret = await repository.revokeSecret(4);

    expect(captured.method, 'DELETE');
    expect(captured.url.path, '/api/v1/secrets/4');
    expect(secret.isRevoked, isTrue);
  });

  test('lê a auditoria com decisões negadas', () async {
    late http.Request captured;
    final repository = _repository((request) async {
      captured = request;
      return _json(
        _envelope(
          [
            {
              'id': 1,
              'area': 'conhecimentos',
              'action': 'READ',
              'result': 'DENIED',
              'target_type': 'knowledge',
              'target_id': 9,
              'created_at': '2026-10-21T11:00:00Z',
            },
            {
              'id': 2,
              'area': 'metas',
              'action': 'CREATE',
              'result': 'ALLOWED',
              'target_type': null,
              'target_id': null,
              'created_at': '2026-10-21T11:05:00Z',
            },
          ],
          meta: {'page': 1, 'per_page': 10, 'total': 2, 'total_pages': 1},
        ),
      );
    });

    final page = await repository.fetchAudit(5, page: 1);

    expect(captured.url.path, '/api/v1/secrets/5/audit');
    expect(captured.url.queryParameters, {'page': '1', 'per_page': '10'});
    expect(page.entries, hasLength(2));
    expect(page.entries.first.isDenied, isTrue);
    expect(page.entries.first.targetId, 9);
    expect(page.entries.last.isDenied, isFalse);
    expect(page.total, 2);
  });
}
