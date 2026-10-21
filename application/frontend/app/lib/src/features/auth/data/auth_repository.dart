import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../domain/auth_session.dart';
import '../domain/user.dart';

class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final envelope = await _client.post(
      '/api/v1/auth/login',
      body: {'username': username, 'password': password},
      parse: _sessionFrom,
    );
    return _requireSession(envelope.data);
  }

  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    final envelope = await _client.post(
      '/api/v1/auth/register',
      body: {'username': username, 'password': password},
      parse: _sessionFrom,
    );
    return _requireSession(envelope.data);
  }

  Future<User> me() async {
    final envelope = await _client.get(
      '/api/v1/auth/me',
      parse: (data) => User.fromJson(Map<String, dynamic>.from(data! as Map)),
    );
    final user = envelope.data;
    if (user == null) {
      throw _invalidResponse();
    }
    return user;
  }

  AuthSession _sessionFrom(Object? data) {
    final json = Map<String, dynamic>.from(data! as Map);
    return AuthSession(
      token: json['access_token'] as String? ?? '',
      user: User.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }

  AuthSession _requireSession(AuthSession? session) {
    if (session == null) {
      throw _invalidResponse();
    }
    return session;
  }

  ApiException _invalidResponse() {
    return const ApiException(
      code: 'INVALID_RESPONSE',
      message: AppStrings.invalidResponse,
    );
  }
}
