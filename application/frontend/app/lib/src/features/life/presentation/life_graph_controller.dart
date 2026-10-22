import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/life_repository.dart';
import '../domain/life_models.dart';

/// Estado do grafo de vida: o que está desenhado, o filtro e as ligações.
class LifeGraphController extends ChangeNotifier {
  LifeGraphController(this._dataSource);

  final LifeDataSource _dataSource;

  LifeGraphData _graph = const LifeGraphData();
  Set<LifeEntityType> _types = const {};
  bool _isLoading = true;
  bool _isBusy = false;
  ApiException? _error;
  int _requestId = 0;

  LifeGraphData get graph => _graph;
  Set<LifeEntityType> get types => _types;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  ApiException? get error => _error;

  Future<void> load({bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading) {
      _isLoading = true;
    }
    _error = null;
    notifyListeners();
    try {
      final graph = await _dataSource.fetchGraph(
        types: _types.toList(growable: false),
      );
      if (requestId != _requestId) {
        return;
      }
      _graph = graph;
    } on ApiException catch (error) {
      if (requestId != _requestId) {
        return;
      }
      _graph = const LifeGraphData();
      _error = error;
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Alterna um tipo no filtro; `null` mostra todos.
  Future<void> toggleType(LifeEntityType type) async {
    final next = {..._types};
    if (!next.remove(type)) {
      next.add(type);
    }
    _types = next;
    await load();
  }

  Future<void> clearTypes() async {
    if (_types.isEmpty) {
      return;
    }
    _types = const {};
    await load();
  }

  /// Liga dois nós. Devolve o erro para a tela mostrar no TOAT.
  Future<ApiException?> connect(
    LifeGraphNode source,
    LifeGraphNode target,
  ) async {
    if (_isBusy) {
      return null;
    }
    _isBusy = true;
    notifyListeners();
    try {
      await _dataSource.link(source, target);
      await load(showLoading: false);
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<ApiException?> disconnect(
    LifeGraphNode source,
    LifeGraphNode target,
  ) async {
    if (_isBusy) {
      return null;
    }
    _isBusy = true;
    notifyListeners();
    try {
      await _dataSource.unlink(source, target);
      await load(showLoading: false);
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
