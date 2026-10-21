// Mantém os nomes públicos dos parâmetros sem expor os campos privados.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/auth_token.dart';
import '../data/auth_repository.dart';
import '../data/session_store.dart';
import '../domain/auth_session.dart';
import '../domain/user.dart';

enum AuthStatus { checking, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository repository,
    required SessionStore store,
    required AuthToken token,
    Duration storeTimeout = const Duration(seconds: 10),
  }) : _repository = repository,
       _store = store,
       _token = token,
       _storeTimeout = storeTimeout;

  final AuthRepository _repository;
  final SessionStore _store;
  final AuthToken _token;

  /// Limite para ler a sessão do armazenamento local: leitura travada não
  /// pode deixar a tela presa em "Verificando sua sessão".
  final Duration _storeTimeout;

  AuthStatus _status = AuthStatus.checking;
  AuthSession? _session;
  bool _isSubmitting = false;
  ApiException? _error;
  Map<String, String> _fieldErrors = const {};

  AuthStatus get status => _status;
  User? get user => _session?.user;
  bool get isSubmitting => _isSubmitting;
  ApiException? get error => _error;
  Map<String, String> get fieldErrors => _fieldErrors;
  bool get isAdmin => user?.isAdmin ?? false;

  /// Retoma a sessão salva. Termina sempre em autenticado ou deslogado:
  /// a tela de "Verificando sua sessão" não pode ficar presa.
  Future<void> restoreSession() async {
    try {
      final storedSession = await _store.read().timeout(
        _storeTimeout,
        onTimeout: () => null,
      );
      if (storedSession == null) {
        _status = AuthStatus.unauthenticated;
        return;
      }

      _session = storedSession;
      _token.value = storedSession.token;

      final currentUser = await _repository.me();
      _session = storedSession.copyWith(user: currentUser);
      await _store.save(_session!);
      _status = AuthStatus.authenticated;
    } on ApiException catch (error) {
      if (error.isUnauthorized || _session == null) {
        await _clearSession();
        _status = AuthStatus.unauthenticated;
      } else {
        // Sem rede, mantém a sessão local para o usuário tentar de novo.
        _status = AuthStatus.authenticated;
      }
    } catch (_) {
      // Sessão ilegível ou resposta fora do envelope: volta ao login.
      await _clearSession();
      _status = AuthStatus.unauthenticated;
    } finally {
      notifyListeners();
    }
  }

  Future<bool> login({required String username, required String password}) {
    return _submit(
      () => _repository.login(username: username, password: password),
    );
  }

  Future<bool> register({required String username, required String password}) {
    return _submit(
      () => _repository.register(username: username, password: password),
    );
  }

  Future<void> logout() async {
    await _clearSession();
    _status = AuthStatus.unauthenticated;
    _error = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  void clearError() {
    if (_error == null && _fieldErrors.isEmpty) {
      return;
    }
    _error = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  Future<bool> _submit(Future<AuthSession> Function() action) async {
    if (_isSubmitting) {
      return false;
    }

    _isSubmitting = true;
    _error = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      final session = await action();
      await _store.save(session);
      _token.value = session.token;
      _session = session;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (error) {
      _error = error;
      _fieldErrors = {
        for (final fieldError in error.errors)
          fieldError.field: fieldError.message,
      };
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    _token.value = null;
    _session = null;
    await _store.clear();
  }
}
