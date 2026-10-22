import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/domain/user.dart';
import '../data/users_repository.dart';

class UsersController extends ChangeNotifier {
  UsersController(this._repository);

  final UsersRepository _repository;

  List<User> _users = const [];
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  ApiException? _error;

  List<User> get users => _users;
  int get total => _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  ApiException? get error => _error;
  bool get hasMore => _page < _totalPages;

  Future<void> loadFirstPage() async {
    if (_isLoading) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _repository.fetchPage(page: 1);
      _users = result.users;
      _page = result.page;
      _total = result.total;
      _totalPages = result.totalPages;
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final result = await _repository.fetchPage(page: _page + 1);
      _users = [..._users, ...result.users];
      _page = result.page;
      _total = result.total;
      _totalPages = result.totalPages;
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadFirstPage();
}
