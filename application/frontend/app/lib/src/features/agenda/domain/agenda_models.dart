import '../../../core/domain/sensitivity_level.dart';
import '../../tags/domain/tag_models.dart';

enum AgendaPriority {
  low,
  medium,
  high;

  static AgendaPriority fromApi(String? value) {
    return switch (value) {
      'HIGH' => AgendaPriority.high,
      'LOW' => AgendaPriority.low,
      _ => AgendaPriority.medium,
    };
  }

  String get apiValue {
    return switch (this) {
      AgendaPriority.low => 'LOW',
      AgendaPriority.medium => 'MEDIUM',
      AgendaPriority.high => 'HIGH',
    };
  }
}

DateTime parseDay(String value) => DateTime.parse(value);

String dateKey(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final dayOfMonth = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$dayOfMonth';
}

bool isSameDay(DateTime? first, DateTime? second) {
  if (first == null || second == null) {
    return false;
  }
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class AgendaActivity {
  const AgendaActivity({
    required this.id,
    required this.title,
    required this.priority,
    required this.isDone,
    this.sensitivity = SensitivityLevel.publico,
    this.startTime,
  });

  final int id;
  final String title;
  final String? startTime;
  final AgendaPriority priority;
  final bool isDone;
  final SensitivityLevel sensitivity;

  factory AgendaActivity.fromJson(Map<String, dynamic> json) {
    return AgendaActivity(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      startTime: json['start_time'] as String?,
      priority: AgendaPriority.fromApi(json['priority'] as String?),
      isDone: json['is_done'] as bool? ?? false,
      sensitivity: SensitivityLevel.fromApi(json['sensitivity'] as String?),
    );
  }
}

class AgendaNote {
  const AgendaNote({
    required this.id,
    required this.content,
    required this.sensitivity,
    this.updatedAt,
  });

  final int id;
  final String content;
  final SensitivityLevel sensitivity;
  final DateTime? updatedAt;

  factory AgendaNote.fromJson(Map<String, dynamic> json) {
    final rawUpdatedAt = json['updated_at'] as String?;
    return AgendaNote(
      id: json['id'] as int,
      content: json['content'] as String? ?? '',
      sensitivity: SensitivityLevel.fromApi(json['sensitivity'] as String?),
      updatedAt: rawUpdatedAt == null ? null : DateTime.tryParse(rawUpdatedAt),
    );
  }
}

class AgendaDaySummary {
  const AgendaDaySummary({
    required this.day,
    required this.hasNote,
    required this.activitiesTotal,
    required this.activitiesDone,
    this.highestPriority,
    this.tags = const [],
    this.holiday,
  });

  final DateTime day;
  final bool hasNote;
  final int activitiesTotal;
  final int activitiesDone;
  final AgendaPriority? highestPriority;
  final List<Tag> tags;

  /// Nome do feriado do dia; nulo quando não é feriado.
  final String? holiday;

  factory AgendaDaySummary.fromJson(Map<String, dynamic> json) {
    return AgendaDaySummary(
      day: parseDay(json['day'] as String),
      hasNote: json['has_note'] as bool? ?? false,
      activitiesTotal: json['activities_total'] as int? ?? 0,
      activitiesDone: json['activities_done'] as int? ?? 0,
      highestPriority: json['highest_priority'] == null
          ? null
          : AgendaPriority.fromApi(json['highest_priority'] as String?),
      tags: _tags(json['tags']),
      holiday: json['holiday'] as String?,
    );
  }
}

class AgendaDay {
  const AgendaDay({
    required this.day,
    required this.activities,
    this.notes = const [],
    this.sensitivity,
    this.tags = const [],
    this.holiday,
  });

  final DateTime day;
  final List<AgendaNote> notes;

  /// Nível do dia (não das notas); nulo quando o dia ainda não tem registro.
  final SensitivityLevel? sensitivity;
  final List<AgendaActivity> activities;
  final List<Tag> tags;

  /// Nome do feriado do dia; nulo quando não é feriado.
  final String? holiday;

  factory AgendaDay.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'];
    final rawNotes = json['notes'];
    final rawSensitivity = json['sensitivity'] as String?;
    return AgendaDay(
      day: parseDay(json['day'] as String),
      notes: rawNotes is List
          ? rawNotes
                .whereType<Map>()
                .map(
                  (item) =>
                      AgendaNote.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      sensitivity: rawSensitivity == null
          ? null
          : SensitivityLevel.fromApi(rawSensitivity),
      tags: _tags(json['tags']),
      holiday: json['holiday'] as String?,
      activities: rawActivities is List
          ? rawActivities
                .whereType<Map>()
                .map(
                  (item) =>
                      AgendaActivity.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }

  int get doneCount => activities.where((activity) => activity.isDone).length;
}

List<Tag> _tags(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => Tag.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
