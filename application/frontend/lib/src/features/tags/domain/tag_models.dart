/// Tipo de registro que pode receber uma tag.
enum TagTarget {
  knowledge('KNOWLEDGE'),
  goal('GOAL'),
  agendaDay('AGENDA_DAY');

  const TagTarget(this.apiValue);

  final String apiValue;

  static TagTarget fromApi(String? value) {
    return switch (value) {
      'GOAL' => TagTarget.goal,
      'AGENDA_DAY' => TagTarget.agendaDay,
      _ => TagTarget.knowledge,
    };
  }
}

class Tag {
  const Tag({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.usageCount,
    this.description,
  });

  final int id;
  final String name;
  final String colorHex;
  final String? description;
  final int usageCount;

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      colorHex: json['color'] as String? ?? '#6B7280',
      description: json['description'] as String?,
      usageCount: json['usage_count'] as int? ?? 0,
    );
  }

  Tag copyWith({
    int? id,
    String? name,
    String? colorHex,
    String? description,
    int? usageCount,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      description: description ?? this.description,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

class TagPage {
  const TagPage({
    required this.tags,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<Tag> tags;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

class TagUsage {
  const TagUsage({
    required this.targetType,
    required this.targetId,
    this.title,
    this.day,
  });

  final TagTarget targetType;
  final int targetId;
  final String? title;
  final DateTime? day;

  factory TagUsage.fromJson(Map<String, dynamic> json) {
    final rawDay = json['day'] as String?;
    return TagUsage(
      targetType: TagTarget.fromApi(json['target_type'] as String?),
      targetId: json['target_id'] as int? ?? 0,
      title: json['title'] as String?,
      day: rawDay == null ? null : DateTime.parse(rawDay),
    );
  }
}

class TagUsagePage {
  const TagUsagePage({
    required this.usages,
    required this.page,
    required this.total,
    required this.totalPages,
  });

  final List<TagUsage> usages;
  final int page;
  final int total;
  final int totalPages;
}
