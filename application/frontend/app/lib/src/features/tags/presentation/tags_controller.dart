import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/tags_repository.dart';
import '../domain/tag_models.dart';
import 'tag_dialogs.dart';

class TagsController extends ChangeNotifier {
  TagsController(this._dataSource);

  final TagsDataSource _dataSource;

  static const int pageSize = 20;

  List<Tag> _tags = const [];
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFetching = false;
  bool _isCreating = false;
  final Set<int> _busyTags = <int>{};
  ApiException? _error;

  List<Tag> get tags => _tags;
  int get total => _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isCreating => _isCreating;
  ApiException? get error => _error;
  bool get hasMore => _page < _totalPages;

  bool isBusy(int tagId) => _busyTags.contains(tagId);

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
      _tags = [..._tags, ...page.tags];
      _applyPage(page);
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<ApiException?> createTag(TagDraft draft) async {
    if (_isCreating) {
      return null;
    }
    _isCreating = true;
    notifyListeners();
    try {
      await _dataSource.createTag(
        name: draft.name,
        colorHex: draft.colorHex,
        description: draft.description,
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

  Future<ApiException?> updateTag(int tagId, TagDraft draft) {
    return _runTagAction(
      tagId,
      () => _dataSource.updateTag(
        tagId,
        name: draft.name,
        colorHex: draft.colorHex,
        description: draft.description,
        changeDescription: true,
      ),
    );
  }

  Future<ApiException?> deleteTag(int tagId) {
    return _runTagAction(tagId, () => _dataSource.deleteTag(tagId));
  }

  Future<ApiException?> _runTagAction(
    int tagId,
    Future<Object?> Function() action,
  ) async {
    if (_busyTags.contains(tagId)) {
      return null;
    }

    _busyTags.add(tagId);
    notifyListeners();
    try {
      await action();
      await _fetchFirstPage(showLoading: false);
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _busyTags.remove(tagId);
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
      _tags = page.tags;
      _applyPage(page);
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyPage(TagPage page) {
    _page = page.page;
    _total = page.total;
    _totalPages = page.totalPages;
  }
}
