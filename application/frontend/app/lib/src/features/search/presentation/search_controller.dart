import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/search_repository.dart';
import '../domain/search_models.dart';

/// Estado da pesquisa universal: termo, filtros e páginas de resultado.
class UniversalSearchController extends ChangeNotifier {
  UniversalSearchController(this._dataSource);

  final SearchDataSource _dataSource;

  String _query = '';
  Set<SearchType> _types = const {};
  DateTime? _from;
  DateTime? _to;
  int? _tagId;
  String? _sensitivity;

  List<SearchResult> _results = const [];
  int _page = 0;
  int _totalPages = 0;
  int _total = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  ApiException? _error;
  int _requestId = 0;

  String get query => _query;
  Set<SearchType> get types => _types;
  DateTime? get from => _from;
  DateTime? get to => _to;
  int? get tagId => _tagId;
  String? get sensitivity => _sensitivity;
  List<SearchResult> get results => _results;
  int get total => _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _page < _totalPages;
  bool get hasQuery => _query.isNotEmpty;
  ApiException? get error => _error;

  Future<void> setQuery(String value) async {
    final term = value.trim();
    if (term == _query) {
      return;
    }
    _query = term;
    await _search();
  }

  /// Alterna um tipo no filtro; vazio mostra todos.
  Future<void> toggleType(SearchType type) async {
    final next = {..._types};
    if (!next.remove(type)) {
      next.add(type);
    }
    _types = next;
    await _search();
  }

  Future<void> clearTypes() async {
    if (_types.isEmpty) {
      return;
    }
    _types = const {};
    await _search();
  }

  Future<void> setPeriod({DateTime? from, DateTime? to}) async {
    _from = from;
    _to = to;
    await _search();
  }

  Future<void> setTag(int? tagId) async {
    _tagId = tagId;
    await _search();
  }

  Future<void> setSensitivity(String? value) async {
    _sensitivity = value;
    await _search();
  }

  Future<void> retry() => _search();

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !hasMore || !hasQuery) {
      return;
    }
    final requestId = _requestId;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final page = await _dataSource.search(
        query: _query,
        page: _page + 1,
        types: _types.toList(growable: false),
        from: _from,
        to: _to,
        tagId: _tagId,
        sensitivity: _sensitivity,
      );
      if (requestId != _requestId) {
        return;
      }
      _results = [..._results, ...page.results];
      _page = page.page;
      _totalPages = page.totalPages;
      _total = page.total;
    } on ApiException catch (error) {
      if (requestId != _requestId) {
        return;
      }
      _error = error;
    } finally {
      if (requestId == _requestId) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _search() async {
    final requestId = ++_requestId;
    if (!hasQuery) {
      _results = const [];
      _page = 0;
      _totalPages = 0;
      _total = 0;
      _isLoading = false;
      _isLoadingMore = false;
      _error = null;
      notifyListeners();
      return;
    }
    _isLoading = true;
    _isLoadingMore = false;
    _error = null;
    notifyListeners();
    try {
      final page = await _dataSource.search(
        query: _query,
        page: 1,
        types: _types.toList(growable: false),
        from: _from,
        to: _to,
        tagId: _tagId,
        sensitivity: _sensitivity,
      );
      if (requestId != _requestId) {
        return;
      }
      _results = page.results;
      _page = page.page;
      _totalPages = page.totalPages;
      _total = page.total;
    } on ApiException catch (error) {
      if (requestId != _requestId) {
        return;
      }
      _results = const [];
      _page = 0;
      _totalPages = 0;
      _total = 0;
      _error = error;
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
