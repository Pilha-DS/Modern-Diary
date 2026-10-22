import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/auth_session.dart';
import '../domain/user.dart';

/// Guarda a sessão local. Em produção, trocar por armazenamento seguro.
///
/// O armazenamento é uma fonte externa: pode estar indisponível, com valor
/// ilegível ou com formato antigo. A leitura nunca lança por isso; sessão
/// inválida é descartada e o usuário volta para o login.
class SessionStore {
  static const String _tokenKey = 'modern_diary_access_token';
  static const String _userKey = 'modern_diary_user';

  Future<AuthSession?> read() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final token = preferences.getString(_tokenKey);
      final rawUser = preferences.getString(_userKey);

      if (token == null || rawUser == null) {
        return null;
      }

      final userJson = jsonDecode(rawUser);
      if (userJson is! Map) {
        await clear();
        return null;
      }

      return AuthSession(
        token: token,
        user: User.fromJson(Map<String, dynamic>.from(userJson)),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> save(AuthSession session) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenKey, session.token);
      await preferences.setString(_userKey, jsonEncode(session.user.toJson()));
    } catch (_) {
      // Sem armazenamento a sessão vale só enquanto a tela estiver aberta.
    }
  }

  Future<void> clear() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_tokenKey);
      await preferences.remove(_userKey);
    } catch (_) {
      // Armazenamento indisponível: não há o que limpar.
    }
  }
}
