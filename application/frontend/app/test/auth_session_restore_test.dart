import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modern_diary/src/core/network/api_client.dart';
import 'package:modern_diary/src/core/network/auth_token.dart';
import 'package:modern_diary/src/features/auth/data/auth_repository.dart';
import 'package:modern_diary/src/features/auth/data/session_store.dart';
import 'package:modern_diary/src/features/auth/domain/auth_session.dart';
import 'package:modern_diary/src/features/auth/domain/user.dart';
import 'package:modern_diary/src/features/auth/presentation/auth_controller.dart';

/// Sessão guardada que não pôde ser lida (armazenamento corrompido).
class _BrokenSessionStore implements SessionStore {
  @override
  Future<AuthSession?> read() async =>
      throw StateError('valor de sessão ilegível');

  @override
  Future<void> save(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

/// Armazenamento que nunca responde.
class _StuckSessionStore implements SessionStore {
  @override
  Future<AuthSession?> read() => Completer<AuthSession?>().future;

  @override
  Future<void> save(AuthSession session) async {}

  @override
  Future<void> clear() async {}
}

/// Sessão guardada válida.
class _StoredSessionStore implements SessionStore {
  _StoredSessionStore(this.session);

  AuthSession? session;

  @override
  Future<AuthSession?> read() async => session;

  @override
  Future<void> save(AuthSession session) async {
    this.session = session;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

http.Response _meEnvelope(int statusCode) {
  return http.Response(
    jsonEncode({
      'code': statusCode == 200 ? 'CURRENT_USER' : 'UNAUTHORIZED',
      'success': statusCode == 200,
      'data': statusCode == 200
          ? {
              'id': 6,
              'username': 'demo_cartao',
              'role': 'USER',
              'created_at': '2026-10-21T15:39:22Z',
            }
          : null,
      'message': null,
      'errors': const [],
      'meta': const {},
      'request_id': 'req_teste',
      'timestamp': '2026-10-21T15:39:22Z',
    }),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

AuthController _controller(
  SessionStore store, {
  int meStatus = 200,
  Duration storeTimeout = const Duration(seconds: 10),
}) {
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8000',
    httpClient: MockClient((request) async => _meEnvelope(meStatus)),
  );
  return AuthController(
    repository: AuthRepository(apiClient),
    store: store,
    token: AuthToken(),
    storeTimeout: storeTimeout,
  );
}

User _user() {
  return User(
    id: 6,
    username: 'demo_cartao',
    role: UserRole.user,
    createdAt: DateTime.utc(2026, 10, 21, 15, 39, 22),
  );
}

void main() {
  test(
    'sessão ilegível não prende a tela em "Verificando sua sessão"',
    () async {
      final controller = _controller(_BrokenSessionStore());

      await controller.restoreSession();

      expect(controller.status, AuthStatus.unauthenticated);
    },
  );

  test('armazenamento travado não prende a tela para sempre', () async {
    final controller = _controller(
      _StuckSessionStore(),
      storeTimeout: const Duration(milliseconds: 20),
    );

    await controller.restoreSession();

    expect(controller.status, AuthStatus.unauthenticated);
  });

  test('sessão salva válida entra direto', () async {
    final store = _StoredSessionStore(
      AuthSession(token: 'token-de-teste', user: _user()),
    );
    final controller = _controller(store);

    await controller.restoreSession();

    expect(controller.status, AuthStatus.authenticated);
    expect(controller.user?.username, 'demo_cartao');
  });

  test('sessão expirada volta para o login e limpa o armazenamento', () async {
    final store = _StoredSessionStore(
      AuthSession(token: 'token-vencido', user: _user()),
    );
    final controller = _controller(store, meStatus: 401);

    await controller.restoreSession();

    expect(controller.status, AuthStatus.unauthenticated);
    expect(store.session, isNull);
  });
}
