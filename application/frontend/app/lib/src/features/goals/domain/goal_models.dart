import '../../../core/domain/sensitivity_level.dart';
import '../../tags/domain/tag_models.dart';

/// Situação usada nos filtros da lista de metas.
enum GoalFilter {
  active('ACTIVE'),
  completed('COMPLETED'),
  archived('ARCHIVED');

  const GoalFilter(this.apiValue);

  final String apiValue;

  static GoalFilter fromApi(String? value) {
    return switch (value) {
      'COMPLETED' => GoalFilter.completed,
      'ARCHIVED' => GoalFilter.archived,
      _ => GoalFilter.active,
    };
  }
}

class GoalStep {
  const GoalStep({
    required this.id,
    required this.title,
    required this.isDone,
    required this.position,
  });

  final int id;
  final String title;
  final bool isDone;
  final int position;

  factory GoalStep.fromJson(Map<String, dynamic> json) {
    return GoalStep(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      isDone: json['is_done'] as bool? ?? false,
      position: json['position'] as int? ?? 0,
    );
  }
}

class Goal {
  const Goal({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.isArchived,
    required this.progressDone,
    required this.progressTotal,
    required this.steps,
    this.sensitivity = SensitivityLevel.publico,
    this.description,
    this.dueDate,
    this.tags = const [],
  });

  final int id;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool isCompleted;
  final bool isArchived;
  final int progressDone;
  final int progressTotal;
  final List<GoalStep> steps;
  final SensitivityLevel sensitivity;
  final List<Tag> tags;

  double get progress {
    if (progressTotal <= 0) {
      return 0;
    }
    return (progressDone / progressTotal).clamp(0, 1);
  }

  bool get hasDescription =>
      description != null && description!.trim().isNotEmpty;

  bool isOverdue(DateTime today) {
    final due = dueDate;
    if (due == null || isCompleted) {
      return false;
    }
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final rawTags = json['tags'];
    final rawDueDate = json['due_date'] as String?;
    return Goal(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      dueDate: rawDueDate == null ? null : DateTime.parse(rawDueDate),
      sensitivity: SensitivityLevel.fromApi(json['sensitivity'] as String?),
      isCompleted: json['is_completed'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      progressDone: json['progress_done'] as int? ?? 0,
      progressTotal: json['progress_total'] as int? ?? 0,
      steps: rawSteps is List
          ? rawSteps
                .whereType<Map>()
                .map(
                  (item) => GoalStep.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      tags: rawTags is List
          ? rawTags
                .whereType<Map>()
                .map((item) => Tag.fromJson(Map<String, dynamic>.from(item)))
                .toList()
          : const [],
    );
  }
}

class GoalsPage {
  const GoalsPage({
    required this.goals,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.counts,
  });

  final List<Goal> goals;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final Map<GoalFilter, int> counts;

  int countFor(GoalFilter filter) => counts[filter] ?? 0;
}
