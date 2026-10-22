/// Registro citado por uma ação da auditoria.
class AuditEntity {
  const AuditEntity({
    required this.type,
    required this.ref,
    required this.label,
  });

  final String type;
  final String ref;
  final String label;

  String get id => '$type:$ref';

  factory AuditEntity.fromJson(Map<String, dynamic> json) {
    return AuditEntity(
      type: json['type'] as String? ?? '',
      ref: json['ref'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

enum AuditEventKind {
  create,
  update,
  delete,
  link,
  unlink;

  static AuditEventKind fromApi(String value) {
    return switch (value) {
      'CREATE' => AuditEventKind.create,
      'UPDATE' => AuditEventKind.update,
      'DELETE' => AuditEventKind.delete,
      'LINK' => AuditEventKind.link,
      'UNLINK' => AuditEventKind.unlink,
      _ => AuditEventKind.update,
    };
  }
}

/// Ação registrada em um dia, com o horário e os registros que ela tocou.
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.occurredAt,
    required this.kind,
    required this.source,
    this.target,
  });

  final int id;
  final DateTime occurredAt;
  final AuditEventKind kind;
  final AuditEntity source;
  final AuditEntity? target;

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    final target = json['target'];
    return AuditEvent(
      id: json['id'] as int? ?? 0,
      occurredAt:
          DateTime.tryParse(json['occurred_at'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      kind: AuditEventKind.fromApi(json['kind'] as String? ?? ''),
      source: AuditEntity.fromJson(
        Map<String, dynamic>.from(json['source'] as Map? ?? const {}),
      ),
      target: target == null
          ? null
          : AuditEntity.fromJson(Map<String, dynamic>.from(target as Map)),
    );
  }
}

/// Quantidade de ações em um dia, usada nas marcas do calendário.
class AuditDaySummary {
  const AuditDaySummary({required this.day, required this.total});

  final DateTime day;
  final int total;

  factory AuditDaySummary.fromJson(Map<String, dynamic> json) {
    return AuditDaySummary(
      day: DateTime.tryParse(json['day'] as String? ?? '') ?? DateTime(1970),
      total: json['total'] as int? ?? 0,
    );
  }
}

class AuditGraphNode {
  const AuditGraphNode({
    required this.id,
    required this.type,
    required this.label,
    required this.degree,
  });

  final String id;
  final String type;
  final String label;
  final int degree;

  factory AuditGraphNode.fromJson(Map<String, dynamic> json) {
    return AuditGraphNode(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      label: json['label'] as String? ?? '',
      degree: json['degree'] as int? ?? 0,
    );
  }
}

class AuditGraphEdge {
  const AuditGraphEdge({required this.source, required this.target});

  final String source;
  final String target;

  factory AuditGraphEdge.fromJson(Map<String, dynamic> json) {
    return AuditGraphEdge(
      source: json['source'] as String? ?? '',
      target: json['target'] as String? ?? '',
    );
  }
}

class AuditGraphData {
  const AuditGraphData({
    this.nodes = const [],
    this.edges = const [],
    this.totalEvents = 0,
    this.truncated = false,
  });

  final List<AuditGraphNode> nodes;
  final List<AuditGraphEdge> edges;
  final int totalEvents;
  final bool truncated;

  bool get isEmpty => nodes.isEmpty;
}

class AuditEventPage {
  const AuditEventPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<AuditEvent> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}
