import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/network/api_envelope.dart';

void main() {
  test('lê o envelope de sucesso com meta', () {
    final envelope = ApiEnvelope<int>.fromJson({
      'code': 'USERS_LISTED',
      'success': true,
      'data': 3,
      'message': null,
      'errors': const [],
      'meta': {'page': 1, 'per_page': 20, 'total': 3, 'total_pages': 1},
      'request_id': 'req_123',
      'timestamp': '2026-10-19T23:00:00Z',
    }, (data) => data! as int);

    expect(envelope.code, 'USERS_LISTED');
    expect(envelope.success, isTrue);
    expect(envelope.data, 3);
    expect(envelope.meta['total'], 3);
    expect(envelope.errors, isEmpty);
  });

  test('lê erros por campo', () {
    final envelope = ApiEnvelope<int>.fromJson({
      'code': 'VALIDATION_ERROR',
      'success': false,
      'data': null,
      'message': 'Verifique os campos.',
      'errors': [
        {
          'field': 'username',
          'code': 'REQUIRED',
          'message': 'Campo obrigatório.',
        },
      ],
      'meta': const {},
      'request_id': 'req_123',
      'timestamp': '2026-10-19T23:00:00Z',
    }, (data) => data! as int);

    expect(envelope.success, isFalse);
    expect(envelope.data, isNull);
    expect(envelope.errors.single.field, 'username');
    expect(envelope.errors.single.code, 'REQUIRED');
  });
}
