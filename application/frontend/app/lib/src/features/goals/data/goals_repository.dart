import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../domain/goal_models.dart';

/// Contrato consumido pelo controller; permite testar sem HTTP.
abstract interface class GoalsDataSource {
  Future<GoalsPage> fetchPage({
    required GoalFilter filter,
    required int page,
    int? perPage,
    int? tagId,
  });

  Future<Goal> fetchGoal(int goalId);

  Future<Goal> createGoal({
    required String title,
    String? description,
    DateTime? dueDate,
    List<String>? steps,
    List<int>? tagIds,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  });

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
  });

  Future<void> deleteGoal(int goalId);

  Future<GoalStep> addStep(int goalId, String title);

  Future<GoalStep> updateStep(int goalId, int stepId, {bool? isDone});

  Future<void> deleteStep(int goalId, int stepId);
}

class GoalsRepository implements GoalsDataSource {
  GoalsRepository(this._client);

  final ApiClient _client;

  static const int perPage = 12;

  @override
  Future<GoalsPage> fetchPage({
    required GoalFilter filter,
    required int page,
    int? perPage,
    int? tagId,
  }) async {
    final requestedPerPage = perPage ?? GoalsRepository.perPage;
    final envelope = await _client.get(
      '/api/v1/goals',
      query: {
        'status': filter.apiValue,
        'page': '$page',
        'per_page': '$requestedPerPage',
        if (tagId != null) 'tag_id': '$tagId',
      },
      parse: (data) {
        final list = data! as List;
        return list
            .whereType<Map>()
            .map((item) => Goal.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      },
    );

    final meta = envelope.meta;
    final rawCounts = meta['counts'];
    final counts = <GoalFilter, int>{};
    if (rawCounts is Map) {
      for (final filter in GoalFilter.values) {
        counts[filter] = readInt(rawCounts[filter.apiValue]);
      }
    }

    return GoalsPage(
      goals: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: requestedPerPage),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
      counts: counts,
    );
  }

  @override
  Future<Goal> fetchGoal(int goalId) async {
    final envelope = await _client.get(
      '/api/v1/goals/$goalId',
      parse: _parseGoal,
    );
    return envelope.data!;
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
    final envelope = await _client.post(
      '/api/v1/goals',
      body: {
        'title': title,
        'description': description,
        'due_date': dueDate == null ? null : _apiDate(dueDate),
        'steps': [
          for (final step in steps ?? const <String>[]) {'title': step},
        ],
        'tag_ids': tagIds ?? const <int>[],
        'sensitivity': sensitivity.apiValue,
      },
      parse: _parseGoal,
    );
    return envelope.data!;
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
    final body = <String, Object?>{};
    if (title != null) {
      body['title'] = title;
    }
    if (changeDescription ?? false) {
      body['description'] = description;
    }
    if (changeTags ?? false) {
      body['tag_ids'] = tagIds ?? const <int>[];
    }
    if (changeDueDate ?? false) {
      body['due_date'] = dueDate == null ? null : _apiDate(dueDate);
    }
    if (isCompleted != null) {
      body['is_completed'] = isCompleted;
    }
    if (isArchived != null) {
      body['is_archived'] = isArchived;
    }
    if (sensitivity != null) {
      body['sensitivity'] = sensitivity.apiValue;
    }

    final envelope = await _client.patch(
      '/api/v1/goals/$goalId',
      body: body,
      parse: _parseGoal,
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteGoal(int goalId) async {
    await _client.delete('/api/v1/goals/$goalId', parse: (_) {});
  }

  @override
  Future<GoalStep> addStep(int goalId, String title) async {
    final envelope = await _client.post(
      '/api/v1/goals/$goalId/steps',
      body: {'title': title},
      parse: _parseStep,
    );
    return envelope.data!;
  }

  @override
  Future<GoalStep> updateStep(int goalId, int stepId, {bool? isDone}) async {
    final envelope = await _client.patch(
      '/api/v1/goals/$goalId/steps/$stepId',
      body: {'is_done': ?isDone},
      parse: _parseStep,
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteStep(int goalId, int stepId) async {
    await _client.delete('/api/v1/goals/$goalId/steps/$stepId', parse: (_) {});
  }

  Goal _parseGoal(Object? data) {
    return Goal.fromJson(Map<String, dynamic>.from(data! as Map));
  }

  GoalStep _parseStep(Object? data) {
    return GoalStep.fromJson(Map<String, dynamic>.from(data! as Map));
  }

  String _apiDate(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }
}
