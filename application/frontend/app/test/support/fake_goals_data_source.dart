import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/features/goals/data/goals_repository.dart';
import 'package:modern_diary/src/features/goals/domain/goal_models.dart';
import 'package:modern_diary/src/features/tags/domain/tag_models.dart';

/// Implementação em memória com a mesma regra do back, para testar sem HTTP.
class FakeGoalsDataSource implements GoalsDataSource {
  FakeGoalsDataSource({List<Goal> initial = const []}) {
    _goals.addAll(initial);
  }

  final List<Goal> _goals = [];
  int _nextId = 1;
  int _nextStepId = 1;
  int fetchCalls = 0;

  List<Goal> get goals => List.unmodifiable(_goals);

  @override
  Future<GoalsPage> fetchPage({
    required GoalFilter filter,
    required int page,
    int? perPage,
    int? tagId,
  }) async {
    fetchCalls++;
    final size = perPage ?? 12;
    final filtered = _goals.where((goal) => _matches(goal, filter)).toList();
    final offset = (page - 1) * size;
    final slice = filtered.skip(offset).take(size).toList();

    return GoalsPage(
      goals: slice,
      page: page,
      perPage: size,
      total: filtered.length,
      totalPages: (filtered.length / size).ceil(),
      counts: {
        for (final value in GoalFilter.values)
          value: _goals.where((goal) => _matches(goal, value)).length,
      },
    );
  }

  @override
  Future<Goal> fetchGoal(int goalId) async {
    return _goals.firstWhere((goal) => goal.id == goalId);
  }

  @override
  Future<Goal> createGoal({
    required String title,
    String? description,
    DateTime? dueDate,
    List<String>? steps,
    List<int>? tagIds,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    final goal = _build(
      id: _nextId++,
      title: title,
      description: description,
      dueDate: dueDate,
      sensitivity: sensitivity,
      steps: [
        for (final stepTitle in steps ?? const <String>[]) _newStep(stepTitle),
      ],
    );
    _goals.add(goal);
    return goal;
  }

  @override
  Future<Goal> updateGoal(
    int goalId, {
    String? title,
    String? description,
    bool? changeDescription,
    DateTime? dueDate,
    bool? changeDueDate,
    bool? isCompleted,
    bool? isArchived,
    List<int>? tagIds,
    bool? changeTags,
    SensitivityLevel? sensitivity,
  }) async {
    final current = _goals.firstWhere((goal) => goal.id == goalId);
    final updated = _build(
      id: current.id,
      title: title ?? current.title,
      description: (changeDescription ?? false)
          ? description
          : current.description,
      dueDate: (changeDueDate ?? false) ? dueDate : current.dueDate,
      sensitivity: sensitivity ?? current.sensitivity,
      isCompleted: isCompleted ?? current.isCompleted,
      isArchived: isArchived ?? current.isArchived,
      steps: current.steps,
      tags: current.tags,
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<void> deleteGoal(int goalId) async {
    _goals.removeWhere((goal) => goal.id == goalId);
  }

  @override
  Future<GoalStep> addStep(int goalId, String title) async {
    final goal = _goals.firstWhere((goal) => goal.id == goalId);
    final step = _newStep(title);
    _replace(
      _build(
        id: goal.id,
        title: goal.title,
        description: goal.description,
        dueDate: goal.dueDate,
        isCompleted: goal.isCompleted,
        isArchived: goal.isArchived,
        steps: [...goal.steps, step],
      ),
    );
    return step;
  }

  @override
  Future<GoalStep> updateStep(int goalId, int stepId, {bool? isDone}) async {
    final goal = _goals.firstWhere((goal) => goal.id == goalId);
    late GoalStep changed;
    final steps = [
      for (final step in goal.steps)
        if (step.id == stepId)
          changed = GoalStep(
            id: step.id,
            title: step.title,
            isDone: isDone ?? step.isDone,
            position: step.position,
          )
        else
          step,
    ];
    _replace(
      _build(
        id: goal.id,
        title: goal.title,
        description: goal.description,
        dueDate: goal.dueDate,
        isCompleted: goal.isCompleted,
        isArchived: goal.isArchived,
        steps: steps,
      ),
    );
    return changed;
  }

  @override
  Future<void> deleteStep(int goalId, int stepId) async {
    final goal = _goals.firstWhere((goal) => goal.id == goalId);
    _replace(
      _build(
        id: goal.id,
        title: goal.title,
        description: goal.description,
        dueDate: goal.dueDate,
        isCompleted: goal.isCompleted,
        isArchived: goal.isArchived,
        steps: goal.steps.where((step) => step.id != stepId).toList(),
      ),
    );
  }

  bool _matches(Goal goal, GoalFilter filter) {
    return switch (filter) {
      GoalFilter.active => !goal.isArchived && !goal.isCompleted,
      GoalFilter.completed => !goal.isArchived && goal.isCompleted,
      GoalFilter.archived => goal.isArchived,
    };
  }

  GoalStep _newStep(String title) {
    return GoalStep(
      id: _nextStepId++,
      title: title,
      isDone: false,
      position: 0,
    );
  }

  Goal _build({
    required int id,
    required String title,
    String? description,
    DateTime? dueDate,
    bool isCompleted = false,
    bool isArchived = false,
    List<GoalStep> steps = const [],
    List<Tag> tags = const [],
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) {
    final done = steps.isEmpty
        ? (isCompleted ? 1 : 0)
        : steps.where((step) => step.isDone).length;
    return Goal(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      isCompleted: isCompleted,
      isArchived: isArchived,
      progressDone: done,
      progressTotal: steps.isEmpty ? 1 : steps.length,
      steps: steps,
      tags: tags,
      sensitivity: sensitivity,
    );
  }

  void _replace(Goal goal) {
    final index = _goals.indexWhere((item) => item.id == goal.id);
    _goals[index] = goal;
  }
}
