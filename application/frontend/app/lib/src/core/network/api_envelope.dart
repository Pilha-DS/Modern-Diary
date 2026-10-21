import 'api_exception.dart';

class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.code,
    required this.success,
    required this.data,
    required this.message,
    required this.errors,
    required this.meta,
    required this.requestId,
    required this.timestamp,
  });

  final String code;
  final bool success;
  final T? data;
  final String? message;
  final List<ApiFieldError> errors;
  final Map<String, dynamic> meta;
  final String requestId;
  final String timestamp;

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) parseData,
  ) {
    final rawErrors = json['errors'];
    final errors = rawErrors is List
        ? rawErrors
              .whereType<Map>()
              .map(
                (error) =>
                    ApiFieldError.fromJson(Map<String, dynamic>.from(error)),
              )
              .toList()
        : <ApiFieldError>[];

    final rawMeta = json['meta'];

    return ApiEnvelope<T>(
      code: json['code'] as String? ?? 'UNKNOWN',
      success: json['success'] as bool? ?? false,
      data: json['data'] == null ? null : parseData(json['data']),
      message: json['message'] as String?,
      errors: errors,
      meta: rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : const {},
      requestId: json['request_id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}
