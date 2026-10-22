import 'package:flutter/foundation.dart';

import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_exception.dart';
import '../data/notes_repository.dart';
import '../domain/note_models.dart';

class NotesController extends ChangeNotifier {
  NotesController(this._dataSource);

  final NotesDataSource _dataSource;

  static const int pageSize = 12;

  String _query = '';
  bool? _pinned;
  List<NoteSummary> _items = const [];
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFetching = false;
  int _requestId = 0;
  bool _isCreating = false;
  final Set<int> _busyNotes = <int>{};
  ApiException? _error;

  String get query => _query;
  bool? get pinned => _pinned;
  List<NoteSummary> get items => _items;
  int get total => _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isCreating => _isCreating;
  ApiException? get error => _error;
  bool get hasMore => _page < _totalPages;
  bool isBusy(int noteId) => _busyNotes.contains(noteId);

  Future<void> loadFirstPage() => _fetchFirstPage(showLoading: true);

  Future<void> refresh() => _fetchFirstPage(showLoading: false);

  Future<void> setQuery(String query) async {
    final cleaned = query.trim();
    if (_query == cleaned) {
      return;
    }
    _query = cleaned;
    await _reloadFirstPage();
  }

  Future<void> setPinned(bool? pinned) async {
    if (_pinned == pinned) {
      return;
    }
    _pinned = pinned;
    await _reloadFirstPage();
  }

  /// Limpa busca e filtro de uma vez, com uma única requisição.
  Future<void> clearFilters() async {
    if (_query.isEmpty && _pinned == null) {
      return;
    }
    _query = '';
    _pinned = null;
    await _reloadFirstPage();
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || _isFetching || !hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();
    final requestId = _requestId;
    try {
      final page = await _dataSource.fetchPage(
        page: _page + 1,
        perPage: pageSize,
        query: _query,
        pinned: _pinned,
      );
      if (requestId != _requestId) {
        return;
      }
      _items = [..._items, ...page.items];
      _applyPage(page);
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

  Future<ApiException?> createNote({
    String? title,
    required String content,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    if (_isCreating) {
      return null;
    }

    _isCreating = true;
    notifyListeners();
    try {
      await _dataSource.createNote(
        title: title,
        content: content,
        sensitivity: sensitivity,
      );
      await _fetchFirstPage(showLoading: false);
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<ApiException?> updateNote(
    int noteId, {
    String? title,
    String? content,
    bool? isPinned,
    SensitivityLevel? sensitivity,
  }) {
    return _runNoteAction(
      noteId,
      () => _dataSource.updateNote(
        noteId,
        title: title,
        changeTitle: true,
        content: content,
        isPinned: isPinned,
        sensitivity: sensitivity,
      ),
    );
  }

  Future<ApiException?> togglePin(NoteSummary note) async {
    final error = await updateNote(note.id, isPinned: !note.isPinned);
    return error;
  }

  Future<ApiException?> deleteNote(int noteId) {
    return _runNoteAction(noteId, () => _dataSource.deleteNote(noteId));
  }

  Future<void> _reloadFirstPage() async {
    _items = const [];
    _page = 0;
    _total = 0;
    _totalPages = 0;
    _error = null;
    notifyListeners();
    await _fetchFirstPage(showLoading: true);
  }

  Future<void> _fetchFirstPage({required bool showLoading}) async {
    // Cada busca ganha um identificador: a resposta de uma busca antiga não
    // pode sobrescrever o resultado da busca atual.
    final requestId = ++_requestId;
    _isFetching = true;
    _isLoadingMore = false;
    if (showLoading) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();

    try {
      final page = await _dataSource.fetchPage(
        page: 1,
        perPage: pageSize,
        query: _query,
        pinned: _pinned,
      );
      if (requestId != _requestId) {
        return;
      }
      _items = page.items;
      _applyPage(page);
    } on ApiException catch (error) {
      if (requestId != _requestId) {
        return;
      }
      _error = error;
    } finally {
      if (requestId == _requestId) {
        _isFetching = false;
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<ApiException?> _runNoteAction(
    int noteId,
    Future<Object?> Function() action,
  ) async {
    if (_busyNotes.contains(noteId)) {
      return null;
    }

    _busyNotes.add(noteId);
    notifyListeners();
    try {
      await action();
      await _fetchFirstPage(showLoading: false);
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _busyNotes.remove(noteId);
      notifyListeners();
    }
  }

  void _applyPage(NotesPage page) {
    _page = page.page;
    _total = page.total;
    _totalPages = page.totalPages;
  }
}
