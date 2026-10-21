// Mantém os nomes públicos dos parâmetros sem expor os campos privados.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../strings/app_strings.dart';
import 'api_envelope.dart';
import 'api_exception.dart';

typedef JsonBody = Map<String, Object?>;

/// Cliente HTTP do envelope único da API. Não conhece regra de negócio.
class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.tokenProvider,
    Duration timeout = const Duration(seconds: 20),
  }) : _baseUrl = baseUrl,
       _httpClient = httpClient ?? http.Client(),
       _timeout = timeout;

  final String _baseUrl;
  final http.Client _httpClient;
  final String? Function()? tokenProvider;
  final Duration _timeout;

  Future<ApiEnvelope<T>> get<T>(
    String path, {
    required T Function(Object? data) parse,
    Map<String, String>? query,
  }) {
    return _request('GET', path, parse: parse, query: query);
  }

  Future<ApiEnvelope<T>> post<T>(
    String path, {
    required T Function(Object? data) parse,
    Object? body,
  }) {
    return _request('POST', path, parse: parse, body: body);
  }

  Future<ApiEnvelope<T>> patch<T>(
    String path, {
    required T Function(Object? data) parse,
    Object? body,
  }) {
    return _request('PATCH', path, parse: parse, body: body);
  }

  Future<ApiEnvelope<T>> put<T>(
    String path, {
    required T Function(Object? data) parse,
    Object? body,
  }) {
    return _request('PUT', path, parse: parse, body: body);
  }

  Future<ApiEnvelope<T>> delete<T>(
    String path, {
    required T Function(Object? data) parse,
    Object? body,
  }) {
    return _request('DELETE', path, parse: parse, body: body);
  }

  /// Envia um arquivo como `multipart/form-data` no campo `file`.
  Future<ApiEnvelope<T>> upload<T>(
    String path, {
    required T Function(Object? data) parse,
    required String filename,
    required List<int> bytes,
    String? contentType,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers(includeContentType: false))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
          contentType: contentType == null
              ? null
              : MediaType.parse(contentType),
        ),
      );

    http.Response response;
    try {
      final streamed = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw _networkException();
    } on http.ClientException {
      throw _networkException();
    }

    return _parseResponse(response, parse);
  }

  Future<ApiEnvelope<T>> _request<T>(
    String method,
    String path, {
    required T Function(Object? data) parse,
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final headers = _headers();
    final encodedBody = body == null ? null : jsonEncode(body);

    http.Response response;
    try {
      response = await switch (method) {
        'GET' => _httpClient.get(uri, headers: headers),
        'POST' => _httpClient.post(uri, headers: headers, body: encodedBody),
        'PATCH' => _httpClient.patch(uri, headers: headers, body: encodedBody),
        'PUT' => _httpClient.put(uri, headers: headers, body: encodedBody),
        'DELETE' => _httpClient.delete(
          uri,
          headers: headers,
          body: encodedBody,
        ),
        _ => throw UnsupportedError('Método HTTP não suportado: $method'),
      }.timeout(_timeout);
    } on TimeoutException {
      throw _networkException();
    } on http.ClientException {
      throw _networkException();
    }

    final decoded = _decodeBody(response);

    return _parseResponse(response, parse, decoded: decoded);
  }

  ApiEnvelope<T> _parseResponse<T>(
    http.Response response,
    T Function(Object? data) parse, {
    Map<String, dynamic>? decoded,
  }) {
    final body = decoded ?? _decodeBody(response);

    try {
      final envelope = ApiEnvelope<T>.fromJson(body, parse);
      if (!envelope.success) {
        throw ApiException(
          code: envelope.code,
          message: envelope.message ?? AppStrings.unexpectedError,
          statusCode: response.statusCode,
          errors: envelope.errors,
        );
      }
      return envelope;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: AppStrings.invalidResponse,
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, dynamic> _decodeBody(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Cai no erro padrão abaixo.
    }
    throw ApiException(
      code: 'INVALID_RESPONSE',
      message: AppStrings.invalidResponse,
      statusCode: response.statusCode,
    );
  }

  void close() {
    _httpClient.close();
  }

  Map<String, String> _headers({bool includeContentType = true}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  ApiException _networkException() {
    return const ApiException(
      code: 'NETWORK_ERROR',
      message: AppStrings.connectionError,
    );
  }
}
