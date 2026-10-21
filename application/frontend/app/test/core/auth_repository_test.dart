import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modern_diary/src/core/network/api_client.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/features/auth/data/auth_repository.dart';
import 'package:modern_diary/src/features/auth/domain/user.dart';

Map<String, dynamic> loginEnvelope() {
  return {
    'code': 'AUTHENTICATED',
    'success': true,
    'data': {
      'access_token': 'token-de-teste',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': {
        'id': 1,
        'username': 'admin',
        'role': 'ADMIN',
        'created_at': '2026-10-19T23:00:00Z',
      },
    },
    'message': 'Login realizado com sucesso.',
    'errors': const [],
    'meta': const {},
    'request_id': 'req_teste',
    'timestamp': '2026-10-19T23:00:00Z',
  };
}

void main() {
  test('envia credenciais e lê a sessão do envelope', () async {
    late http.Request capturedRequest;
    final httpClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode(loginEnvelope()),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: httpClient,
      tokenProvider: () => 'token-anterior',
    );
    final session = await AuthRepository(apiClient)
        .login(username: 'admin', password: 'admin1234');

    expect(capturedRequest.url.path, '/api/v1/auth/login');
    expect(capturedRequest.headers['Authorization'], 'Bearer token-anterior');
    expect(jsonDecode(capturedRequest.body), {
      'username': 'admin',
      'password': 'admin1234',
    });
    expect(session.token, 'token-de-teste');
    expect(session.user.username, 'admin');
    expect(session.user.role, UserRole.admin);
    expect(session.user.isAdmin, isTrue);
  });

  test('transforma erro do envelope em ApiException', () async {
    final httpClient = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'code': 'INVALID_CREDENTIALS',
          'success': false,
          'data': null,
          'message': 'Usuário ou senha incorretos.',
          'errors': const [],
          'meta': const {},
          'request_id': 'req_teste',
          'timestamp': '2026-10-19T23:00:00Z',
        }),
        401,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: httpClient,
    );

    await expectLater(
      AuthRepository(apiClient).login(username: 'admin', password: 'errada'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'INVALID_CREDENTIALS')
            .having((error) => error.isUnauthorized, 'isUnauthorized', isTrue),
      ),
    );
  });
}
