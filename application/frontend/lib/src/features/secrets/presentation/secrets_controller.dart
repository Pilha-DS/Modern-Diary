import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/secrets_repository.dart';
import '../domain/secret_models.dart';
import 'secret_form_dialog.dart';

/// Resultado de criar ou trocar um token: o token só vem uma vez.
typedef SecretTokenResult = ({SecretCreation? creation, ApiException? error});

class SecretsController extends ChangeNotifier {
  SecretsController(this._dataSource);

  final SecretsDataSource _dataSource;

  static const int pageSize = 10;

  List<ApiSecret> _secrets = const [];
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFetching = false;
  bool _isCreating = false;
  final Set<int> _busySecrets = <int>{};
  ApiException? _error;

  List<ApiSecret> get secrets => _secrets;
  int get total => _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isCreating => _isCreating;
  ApiException? get error => _error;
  bool get hasMore => _page < _totalPages;

  bool isBusy(int secretId) => _busySecrets.contains(secretId);

  Future<void> loadFirstPage() => _fetchFirstPage(showLoading: true);

  Future<void> refresh() => _fetchFirstPage(showLoading: false);

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || _isFetching || !hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _dataSource.fetchPage(
        page: _page + 1,
        perPage: pageSize,
      );
      _secrets = [..._secrets, ...page.secrets];
      _applyPage(page);
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<SecretTokenResult> createSecret(SecretDraft draft) async {
    if (_isCreating) {
      return (creation: null, error: null);
    }

    _isCreating = true;
    notifyListeners();
    try {
      final creation = await _dataSource.createSecret(
        name: draft.name,
        permissions: draft.permissions,
      );
      await _fetchFirstPage(showLoading: false);
      return (creation: creation, error: null);
    } on ApiException catch (error) {
      return (creation: null, error: error);
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<ApiException?> updateSecret(int secretId, SecretDraft draft) {
    return _runSecretAction(
      secretId,
      () => _dataSource.updateSecret(
        secretId,
        name: draft.name,
        permissions: draft.permissions,
      ),
    );
  }

  Future<SecretTokenResult> rotate(int secretId) async {
    if (_busySecrets.contains(secretId)) {
      return (creation: null, error: null);
    }

    _busySecrets.add(secretId);
    notifyListeners();
    try {
      final creation = await _dataSource.rotateSecret(secretId);
      await _fetchFirstPage(showLoading: false);
      return (creation: creation, error: null);
    } on ApiException catch (error) {
      return (creation: null, error: error);
    } finally {
      _busySecrets.remove(secretId);
      notifyListeners();
    }
  }

  Future<ApiException?> revoke(int secretId) {
    return _runSecretAction(secretId, () => _dataSource.revokeSecret(secretId));
  }

  Future<ApiException?> _runSecretAction(
    int secretId,
    Future<Object?> Function() action,
  ) async {
    if (_busySecrets.contains(secretId)) {
      return null;
    }

    _busySecrets.add(secretId);
    notifyListeners();
    try {
      await action();
      await _fetchFirstPage(showLoading: false);
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _busySecrets.remove(secretId);
      notifyListeners();
    }
  }

  Future<void> _fetchFirstPage({required bool showLoading}) async {
    if (_isFetching) {
      return;
    }

    _isFetching = true;
    if (showLoading) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final page = await _dataSource.fetchPage(page: 1, perPage: pageSize);
      _secrets = page.secrets;
      _applyPage(page);
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyPage(SecretsPage page) {
    _page = page.page;
    _total = page.total;
    _totalPages = page.totalPages;
  }
}
