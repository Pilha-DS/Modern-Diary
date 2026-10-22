import '../../../core/domain/sensitivity_level.dart';

/// Resumo de uma nota para a lista: o conteúdo vem cortado em [preview].
class NoteSummary {
  const NoteSummary({
    required this.id,
    required this.preview,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.sensitivity = SensitivityLevel.publico,
  });

  final int id;
  final String? title;
  final String preview;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SensitivityLevel sensitivity;

  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  factory NoteSummary.fromJson(Map<String, dynamic> json) {
    return NoteSummary(
      id: json['id'] as int,
      title: json['title'] as String?,
      preview: json['preview'] as String? ?? '',
      isPinned: json['is_pinned'] as bool? ?? false,
      sensitivity: SensitivityLevel.fromApi(json['sensitivity'] as String?),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

/// Nota completa, com o markdown inteiro.
class Note {
  const Note({
    required this.id,
    required this.content,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.title,
    this.sensitivity = SensitivityLevel.publico,
  });

  final int id;
  final String? title;
  final String content;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SensitivityLevel sensitivity;

  bool get hasTitle => title != null && title!.trim().isNotEmpty;

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int,
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      isPinned: json['is_pinned'] as bool? ?? false,
      sensitivity: SensitivityLevel.fromApi(json['sensitivity'] as String?),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }
}

class NotesPage {
  const NotesPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<NoteSummary> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

DateTime _parseDate(Object? raw) {
  return DateTime.parse(raw as String? ?? '1970-01-01T00:00:00');
}
