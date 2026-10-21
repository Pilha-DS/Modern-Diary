import '../../../core/domain/sensitivity_level.dart';
import '../../tags/domain/tag_models.dart';

/// Link externo guardado dentro de um conhecimento.
class KnowledgeExternalLink {
  const KnowledgeExternalLink({required this.url, this.label});

  final String url;
  final String? label;

  String get displayLabel => (label == null || label!.isEmpty) ? url : label!;

  factory KnowledgeExternalLink.fromJson(Map<String, dynamic> json) {
    return KnowledgeExternalLink(
      url: json['url'] as String? ?? '',
      label: json['label'] as String?,
    );
  }

  Map<String, Object?> toJson() => {'url': url, 'label': label};
}

class KnowledgeAttachment {
  const KnowledgeAttachment({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.downloadUrl,
  });

  final int id;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String downloadUrl;

  factory KnowledgeAttachment.fromJson(Map<String, dynamic> json) {
    return KnowledgeAttachment(
      id: json['id'] as int,
      filename: json['filename'] as String? ?? '',
      contentType: json['content_type'] as String? ?? '',
      sizeBytes: json['size_bytes'] as int? ?? 0,
      downloadUrl: json['download_url'] as String? ?? '',
    );
  }
}

/// Referência a outro conhecimento conectado.
class KnowledgeReference {
  const KnowledgeReference({required this.id, required this.title});

  final int id;
  final String title;

  factory KnowledgeReference.fromJson(Map<String, dynamic> json) {
    return KnowledgeReference(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
    );
  }
}

/// Referência a uma meta ligada a um conhecimento.
class KnowledgeGoalReference {
  const KnowledgeGoalReference({required this.id, required this.title});

  final int id;
  final String title;

  factory KnowledgeGoalReference.fromJson(Map<String, dynamic> json) {
    return KnowledgeGoalReference(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
    );
  }
}

class KnowledgeItem {
  const KnowledgeItem({
    required this.id,
    required this.title,
    required this.links,
    required this.relations,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.sensitivity = SensitivityLevel.publico,
    this.content,
    this.goals = const [],
    this.tags = const [],
  });

  final int id;
  final String title;
  final String? content;
  final List<KnowledgeExternalLink> links;
  final List<KnowledgeReference> relations;
  final List<KnowledgeAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SensitivityLevel sensitivity;
  final List<KnowledgeGoalReference> goals;
  final List<Tag> tags;

  bool get hasContent => content != null && content!.trim().isNotEmpty;

  factory KnowledgeItem.fromJson(Map<String, dynamic> json) {
    return KnowledgeItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      sensitivity: SensitivityLevel.fromApi(json['sensitivity'] as String?),
      links: _list(json['links'], KnowledgeExternalLink.fromJson),
      relations: _list(json['relations'], KnowledgeReference.fromJson),
      goals: _list(json['goals'], KnowledgeGoalReference.fromJson),
      tags: _list(json['tags'], Tag.fromJson),
      attachments: _list(json['attachments'], KnowledgeAttachment.fromJson),
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? '1970-01-01T00:00:00',
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? '1970-01-01T00:00:00',
      ),
    );
  }
}

class KnowledgePage {
  const KnowledgePage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<KnowledgeItem> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

class KnowledgeNodeData {
  const KnowledgeNodeData({
    required this.id,
    required this.title,
    required this.degree,
    this.sensitivity = SensitivityLevel.publico,
    this.tags = const [],
  });

  final int id;
  final String title;
  final int degree;
  final SensitivityLevel sensitivity;
  final List<Tag> tags;

  factory KnowledgeNodeData.fromJson(Map<String, dynamic> json) {
    return KnowledgeNodeData(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      degree: json['degree'] as int? ?? 0,
      sensitivity: SensitivityLevel.fromApi(json['sensitivity'] as String?),
      tags: _list(json['tags'], Tag.fromJson),
    );
  }
}

class KnowledgeEdge {
  const KnowledgeEdge({required this.source, required this.target});

  final int source;
  final int target;

  factory KnowledgeEdge.fromJson(Map<String, dynamic> json) {
    return KnowledgeEdge(
      source: json['source'] as int,
      target: json['target'] as int,
    );
  }
}

class KnowledgeGraphData {
  const KnowledgeGraphData({
    required this.nodes,
    required this.edges,
    required this.total,
    required this.truncated,
  });

  final List<KnowledgeNodeData> nodes;
  final List<KnowledgeEdge> edges;
  final int total;
  final bool truncated;
}

/// Arquivo escolhido no formulário, antes de ir para a API.
class KnowledgeUploadFile {
  const KnowledgeUploadFile({
    required this.filename,
    required this.bytes,
    required this.contentType,
  });

  final String filename;
  final List<int> bytes;
  final String contentType;
}

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => parse(Map<String, dynamic>.from(item)))
      .toList();
}
