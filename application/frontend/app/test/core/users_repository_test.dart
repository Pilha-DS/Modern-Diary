import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:modern_diary/src/core/network/api_client.dart';
import 'package:modern_diary/src/features/users/data/users_repository.dart';

void main() {
  test('lê usuários e paginação do meta', () async {
    late http.Request capturedRequest;
    final httpClient = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'code': 'USERS_LISTED',
          'success': true,
          'data': [
            {
              'id': 1,
              'username': 'admin',
              'role': 'ADMIN',
              'created_at': '2026-10-19T23:00:00Z',
            },
          ],
          'message': null,
          'errors': const [],
          'meta': {'page': 2, 'per_page': 20, 'total': 21, 'total_pages': 2},
          'request_id': 'req_teste',
          'timestamp': '2026-10-19T23:00:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final apiClient = ApiClient(
      baseUrl: 'http://localhost:8000',
      httpClient: httpClient,
    );
    final page = await UsersRepository(apiClient).fetchPage(page: 2);

    expect(capturedRequest.url.queryParameters, {
      'page': '2',
      'per_page': '20',
    });
    expect(page.users.single.username, 'admin');
    expect(page.page, 2);
    expect(page.total, 21);
    expect(page.totalPages, 2);
  });
}
