import 'package:flutter/foundation.dart';

import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_exception.dart';
import '../data/knowledge_repository.dart';
import '../domain/knowledge_models.dart';

enum KnowledgeView { list, graph }

class KnowledgeController extends ChangeNotifier {
  KnowledgeController(this._dataSource);

  final KnowledgeDataSource _dataSource;

  static const int pageSize = 12;

  KnowledgeView _view = KnowledgeView.list;
  int? _tagId;
  List<KnowledgeItem> _items = const [];
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFetching = false;
  bool _isCreating = false;
  final Set<int> _busyItems = <int>{};
  ApiException? _error;

  KnowledgeGraphData? _graph;
  bool _isLoadingGraph = false;
  bool _graphReloadPending = false;
  ApiException? _graphError;

  KnowledgeView get view => _view;
  int? get tagId => _tagId;
  List<KnowledgeItem> get items => _items;
  int get total => _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isCreating => _isCreating;
  ApiException? get error => _error;
  bool get hasMore => _page < _totalPages;
  bool isBusy(int itemId) => _busyItems.contains(itemId);

  KnowledgeGraphData? get graph => _graph;
  bool get isLoadingGraph => _isLoadingGraph;
  ApiException? get graphError => _graphError;

  Future<void> setView(KnowledgeView view) async {
    if (_view == view) {
      return;
    }
    _view = view;
    notifyListeners();
    if (view == KnowledgeView.graph && _graph == null) {
      await loadGraph();
    }
  }

  Future<void> setTagFilter(int? tagId) async {
    if (_tagId == tagId) {
      return;
    }
    _tagId = tagId;
    _items = const [];
    _page = 0;
    _total = 0;
    _totalPages = 0;
    _error = null;
    _graph = null;
    notifyListeners();
    await loadFirstPage();
    if (_view == KnowledgeView.graph) {
      await loadGraph();
    }
  }

  Future<void> loadFirstPage() => _fetchFirstPage(showLoading: true);

  Future<void> refresh() async {
    await _fetchFirstPage(showLoading: false);
    if (_graph != null) {
      await loadGraph();
    }
  }

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
        tagId: _tagId,
      );
      _items = [..._items, ...page.items];
      _applyPage(page);
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadGraph() async {
    if (_isLoadingGraph) {
      // Já existe uma busca em andamento: a próxima começa quando ela acabar,
      // para a conexão recém-criada não ficar de fora do grafo.
      _graphReloadPending = true;
      return;
    }

    _isLoadingGraph = true;
    _graphError = null;
    notifyListeners();

    try {
      _graph = await _dataSource.fetchGraph(tagId: _tagId);
    } on ApiException catch (error) {
      _graphError = error;
    } finally {
      _isLoadingGraph = false;
      notifyListeners();
      if (_graphReloadPending) {
        _graphReloadPending = false;
        await loadGraph();
      }
    }
  }

  Future<ApiException?> createItem({
    required String title,
    String? content,
    List<KnowledgeExternalLink> links = const [],
    List<KnowledgeUploadFile> files = const [],
    List<int> tagIds = const [],
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    if (_isCreating) {
      return null;
    }

    _isCreating = true;
    notifyListeners();
    try {
      final item = await _dataSource.createItem(
        title: title,
        content: content,
        links: links,
        tagIds: tagIds,
        sensitivity: sensitivity,
      );
      final uploadError = await _uploadAll(item.id, files);
      await _reloadAfterChange();
      return uploadError;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  Future<ApiException?> updateItem(
    int itemId, {
    required String title,
    String? content,
    List<KnowledgeExternalLink> links = const [],
    List<KnowledgeUploadFile> files = const [],
    List<int> tagIds = const [],
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) {
    return _runItemAction(itemId, () async {
      await _dataSource.updateItem(
        itemId,
        title: title,
        content: content,
        changeContent: true,
        links: links,
        changeLinks: true,
        tagIds: tagIds,
        changeTags: true,
        sensitivity: sensitivity,
      );
      return _uploadAll(itemId, files);
    });
  }

  Future<ApiException?> deleteItem(int itemId) {
    return _runItemAction(itemId, () => _dataSource.deleteItem(itemId));
  }

  Future<ApiException?> updateLinks(
    int itemId,
    List<KnowledgeExternalLink> links,
  ) {
    return _runItemAction(
      itemId,
      () => _dataSource.updateItem(itemId, links: links, changeLinks: true),
    );
  }

  /// Troca só o conteúdo: não mexe em links, tags nem anexos.
  Future<ApiException?> updateContent(int itemId, String? content) {
    return _runItemAction(
      itemId,
      () =>
          _dataSource.updateItem(itemId, content: content, changeContent: true),
    );
  }

  Future<ApiException?> addRelation(int itemId, int targetId) {
    return _runItemAction(
      itemId,
      () => _dataSource.addRelation(itemId, targetId),
    );
  }

  Future<ApiException?> removeRelation(int itemId, int targetId) {
    return _runItemAction(
      itemId,
      () => _dataSource.removeRelation(itemId, targetId),
    );
  }

  Future<ApiException?> addGoal(int itemId, int goalId) {
    return _runItemAction(itemId, () => _dataSource.addGoal(itemId, goalId));
  }

  Future<ApiException?> removeGoal(int itemId, int goalId) {
    return _runItemAction(itemId, () => _dataSource.removeGoal(itemId, goalId));
  }

  Future<ApiException?> uploadAttachment(int itemId, KnowledgeUploadFile file) {
    return _runItemAction(
      itemId,
      () => _dataSource.uploadAttachment(itemId, file),
    );
  }

  Future<ApiException?> deleteAttachment(int itemId, int attachmentId) {
    return _runItemAction(
      itemId,
      () => _dataSource.deleteAttachment(itemId, attachmentId),
    );
  }

  /// Devolve a observação criada para o modal mostrar sem recarregar o item.
  Future<(KnowledgeObservation?, ApiException?)> addObservation(
    int itemId,
    String text,
  ) async {
    if (_busyItems.contains(itemId)) {
      return (null, null);
    }
    _busyItems.add(itemId);
    notifyListeners();
    try {
      final observation = await _dataSource.addObservation(itemId, text);
      await _reloadAfterChange();
      return (observation, null);
    } on ApiException catch (error) {
      return (null, error);
    } finally {
      _busyItems.remove(itemId);
      notifyListeners();
    }
  }

  Future<ApiException?> deleteObservation(int itemId, int observationId) {
    return _runItemAction(
      itemId,
      () => _dataSource.deleteObservation(itemId, observationId),
    );
  }

  Uri attachmentDownloadUri(KnowledgeAttachment attachment) =>
      _dataSource.attachmentDownloadUri(attachment);

  Future<ApiException?> _uploadAll(
    int itemId,
    List<KnowledgeUploadFile> files,
  ) async {
    for (final file in files) {
      try {
        await _dataSource.uploadAttachment(itemId, file);
      } on ApiException catch (error) {
        return error;
      }
    }
    return null;
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
      final page = await _dataSource.fetchPage(
        page: 1,
        perPage: pageSize,
        tagId: _tagId,
      );
      _items = page.items;
      _applyPage(page);
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ApiException?> _runItemAction(
    int itemId,
    Future<Object?> Function() action,
  ) async {
    if (_busyItems.contains(itemId)) {
      return null;
    }

    _busyItems.add(itemId);
    notifyListeners();
    try {
      final result = await action();
      await _reloadAfterChange();
      return result is ApiException ? result : null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _busyItems.remove(itemId);
      notifyListeners();
    }
  }

  Future<void> _reloadAfterChange() async {
    await _fetchFirstPage(showLoading: false);
    if (_view == KnowledgeView.graph) {
      // Mantém a rede atual na tela enquanto a nova chega: o grafo não perde
      // a posição dos nós nem o modo de conexão a cada alteração.
      await loadGraph();
    }
  }

  void _applyPage(KnowledgePage page) {
    _page = page.page;
    _total = page.total;
    _totalPages = page.totalPages;
  }
}
