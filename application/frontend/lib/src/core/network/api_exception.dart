class ApiFieldError {
  const ApiFieldError({
    required this.field,
    required this.code,
    required this.message,
  });

  final String field;
  final String code;
  final String message;

  factory ApiFieldError.fromJson(Map<String, dynamic> json) {
    return ApiFieldError(
      field: json['field'] as String? ?? '',
      code: json['code'] as String? ?? 'INVALID_VALUE',
      message: json['message'] as String? ?? 'Valor inválido.',
    );
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.errors = const [],
  });

  final String code;
  final String message;
  final int? statusCode;
  final List<ApiFieldError> errors;

  bool get isUnauthorized {
    return statusCode == 401 ||
        code == 'UNAUTHORIZED' ||
        code == 'INVALID_TOKEN' ||
        code == 'TOKEN_EXPIRED';
  }

  bool get isNetwork => code == 'NETWORK_ERROR';

  @override
  String toString() =>
      'ApiException($code, status: $statusCode, message: $message)';
}
