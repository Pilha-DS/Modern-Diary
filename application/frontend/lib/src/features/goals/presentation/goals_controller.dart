import 'package:flutter/foundation.dart';

import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_exception.dart';
import '../data/goals_repository.dart';
import '../domain/goal_models.dart';

class GoalsController extends ChangeNotifier {
  GoalsController(this._dataSource);

  final GoalsDataSource _dataSource;

  /// Doze metas por página, exibidas em três colunas.
  static const int pageSize = 12;

  GoalFilter _filter = GoalFilter.active;
  int? _tagId;
  List<Goal> _goals = const [];
  Map<GoalFilter, int> _counts = const {};
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFetching = false;
  bool _isCreating = false;
  final Set<int> _busyGoals = <int>{};
  ApiException? _error;

  GoalFilter get filter => _filter;
  int? get tagId => _tagId;
  List<Goal> get goals => _goals;
  int get total => _total;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isCreating => _isCreating;
  ApiException? get error => _error;
  bool get hasMore => _page < _totalPages;

  int countFor(GoalFilter filter) => _counts[filter] ?? 0;

  bool isBusy(int goalId) => _busyGoals.contains(goalId);

  Future<void> loadFirstPage() => _fetchFirstPage(showLoading: true);

  Future<void> refresh() => _fetchFirstPage(showLoading: false);

  Future<void> setFilter(GoalFilter filter) async {
    if (_filter == filter) {
      return;
    }
    _filter = filter;
    await _reload();
  }

  Future<void> setTagFilter(int? tagId) async {
    if (_tagId == tagId) {
      return;
    }
    _tagId = tagId;
    await _reload();
  }

  Future<void> _reload() async {
    _goals = const [];
    _page = 0;
    _total = 0;
    _totalPages = 0;
    _error = null;
    notifyListeners();
    await loadFirstPage();
  }

  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || _isFetching || !hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      final page = await _dataSource.fetchPage(
        filter: _filter,
        page: _page + 1,
        perPage: pageSize,
        tagId: _tagId,
      );
      _goals = [..._goals, ...page.goals];
      _applyMeta(page);
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<ApiException?> createGoal({
    required String title,
    String? description,
    DateTime? dueDate,
    List<String> steps = const [],
    List<int> tagIds = const [],
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    if (_isCreating) {
      return null;
    }

    _isCreating = true;
    notifyListeners();
    try {
      await _dataSource.createGoal(
        title: title,
        description: description,
        dueDate: dueDate,
        steps: steps,
        tagIds: tagIds,
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

  Future<ApiException?> updateGoal(
    int goalId, {
    required String title,
    String? description,
    DateTime? dueDate,
    List<int> tagIds = const [],
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) {
    return _runGoalAction(
      goalId,
      () => _dataSource.updateGoal(
        goalId,
        title: title,
        description: description,
        changeDescription: true,
        dueDate: dueDate,
        changeDueDate: true,
        tagIds: tagIds,
        changeTags: true,
        sensitivity: sensitivity,
      ),
    );
  }

  Future<ApiException?> setCompleted(int goalId, {required bool completed}) {
    return _runGoalAction(
      goalId,
      () => _dataSource.updateGoal(goalId, isCompleted: completed),
    );
  }

  Future<ApiException?> setArchived(int goalId, {required bool archived}) {
    return _runGoalAction(
      goalId,
      () => _dataSource.updateGoal(goalId, isArchived: archived),
    );
  }

  Future<ApiException?> deleteGoal(int goalId) {
    return _runGoalAction(goalId, () => _dataSource.deleteGoal(goalId));
  }

  Future<ApiException?> addStep(int goalId, String title) {
    return _runGoalAction(goalId, () => _dataSource.addStep(goalId, title));
  }

  Future<ApiException?> toggleStep(int goalId, GoalStep step) {
    return _runGoalAction(
      goalId,
      () => _dataSource.updateStep(goalId, step.id, isDone: !step.isDone),
    );
  }

  Future<ApiException?> deleteStep(int goalId, int stepId) {
    return _runGoalAction(goalId, () => _dataSource.deleteStep(goalId, stepId));
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
        filter: _filter,
        page: 1,
        perPage: pageSize,
        tagId: _tagId,
      );
      _goals = page.goals;
      _applyMeta(page);
    } on ApiException catch (error) {
      _error = error;
    } finally {
      _isFetching = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ApiException?> _runGoalAction(
    int goalId,
    Future<Object?> Function() action,
  ) async {
    if (_busyGoals.contains(goalId)) {
      return null;
    }

    _busyGoals.add(goalId);
    notifyListeners();
    try {
      await action();
      await _fetchFirstPage(showLoading: false);
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _busyGoals.remove(goalId);
      notifyListeners();
    }
  }

  void _applyMeta(GoalsPage page) {
    _page = page.page;
    _total = page.total;
    _totalPages = page.totalPages;
    _counts = page.counts;
  }
}
