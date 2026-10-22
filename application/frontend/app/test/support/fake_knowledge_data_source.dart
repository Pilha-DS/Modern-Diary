import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/features/knowledge/data/knowledge_repository.dart';
import 'package:modern_diary/src/features/knowledge/domain/knowledge_models.dart';

/// Implementação em memória com a mesma regra do back, para testar sem HTTP.
class FakeKnowledgeDataSource implements KnowledgeDataSource {
  FakeKnowledgeDataSource({List<KnowledgeItem> initial = const []}) {
    _items.addAll(initial);
    _nextId = _items.fold(0, (max, item) => item.id > max ? item.id : max) + 1;
  }

  final List<KnowledgeItem> _items = [];
  late int _nextId;
  int _nextAttachmentId = 1;
  int _nextObservationId = 1;
  int fetchCalls = 0;
  int graphCalls = 0;
  int? lastGraphTagId;

  List<KnowledgeItem> get items => List.unmodifiable(_items);

  @override
  Future<KnowledgePage> fetchPage({
    required int page,
    int? perPage,
    int? tagId,
  }) async {
    fetchCalls++;
    final size = perPage ?? 12;
    final offset = (page - 1) * size;
    final filtered = tagId == null
        ? _items
        : _items
              .where((item) => item.tags.any((tag) => tag.id == tagId))
              .toList();

    return KnowledgePage(
      items: filtered.skip(offset).take(size).toList(),
      page: page,
      perPage: size,
      total: filtered.length,
      totalPages: (filtered.length / size).ceil(),
    );
  }

  @override
  Future<KnowledgeGraphData> fetchGraph({int? tagId}) async {
    graphCalls++;
    lastGraphTagId = tagId;
    final items = tagId == null
        ? _items
        : _items
              .where((item) => item.tags.any((tag) => tag.id == tagId))
              .toList();
    final ids = {for (final item in items) item.id};
    final degrees = <int, int>{for (final item in items) item.id: 0};
    final seen = <String>{};
    final edges = <KnowledgeEdge>[];

    for (final item in items) {
      for (final relation in item.relations) {
        if (!ids.contains(relation.id)) {
          continue;
        }
        degrees[item.id] = (degrees[item.id] ?? 0) + 1;
        degrees[relation.id] = (degrees[relation.id] ?? 0) + 1;
        final low = item.id < relation.id ? item.id : relation.id;
        final high = item.id < relation.id ? relation.id : item.id;
        if (seen.add('$low-$high')) {
          edges.add(KnowledgeEdge(source: low, target: high));
        }
      }
    }

    return KnowledgeGraphData(
      nodes: [
        for (final item in items)
          KnowledgeNodeData(
            id: item.id,
            title: item.title,
            degree: degrees[item.id] ?? 0,
            sensitivity: item.sensitivity,
            tags: item.tags,
          ),
      ],
      edges: edges,
      total: items.length,
      truncated: false,
    );
  }

  @override
  Future<KnowledgeItem> fetchItem(int itemId) async {
    return _items.firstWhere((item) => item.id == itemId);
  }

  @override
  Future<KnowledgeItem> createItem({
    required String title,
    String? content,
    List<KnowledgeExternalLink>? links,
    List<int>? tagIds,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    final item = KnowledgeItem(
      id: _nextId++,
      title: title,
      content: content,
      links: links ?? const [],
      sensitivity: sensitivity,
      relations: const [],
      attachments: const [],
      goals: const [],
      tags: const [],
      createdAt: DateTime(2026, 10, 20),
      updatedAt: DateTime(2026, 10, 20),
    );
    _items.insert(0, item);
    return item;
  }

  @override
  Future<KnowledgeItem> updateItem(
    int itemId, {
    String? title,
    String? content,
    bool? changeContent,
    List<KnowledgeExternalLink>? links,
    bool? changeLinks,
    List<int>? tagIds,
    bool? changeTags,
    SensitivityLevel? sensitivity,
  }) async {
    final current = await fetchItem(itemId);
    final updated = KnowledgeItem(
      id: current.id,
      title: title ?? current.title,
      content: (changeContent ?? false) ? content : current.content,
      links: (changeLinks ?? false) ? (links ?? const []) : current.links,
      sensitivity: sensitivity ?? current.sensitivity,
      relations: current.relations,
      attachments: current.attachments,
      goals: current.goals,
      tags: current.tags,
      createdAt: current.createdAt,
      updatedAt: DateTime(2026, 10, 21),
    );
    _replace(updated);
    return updated;
  }

  @override
  Future<void> deleteItem(int itemId) async {
    _items.removeWhere((item) => item.id == itemId);
    for (var index = 0; index < _items.length; index++) {
      _items[index] = _withoutRelation(_items[index], itemId);
    }
  }

  @override
  Future<void> addRelation(int itemId, int targetId) async {
    final item = await fetchItem(itemId);
    final target = await fetchItem(targetId);
    _replace(_withRelation(item, target));
    _replace(_withRelation(target, item));
  }

  @override
  Future<void> removeRelation(int itemId, int targetId) async {
    _replace(_withoutRelation(await fetchItem(itemId), targetId));
    _replace(_withoutRelation(await fetchItem(targetId), itemId));
  }

  @override
  Future<void> addGoal(int itemId, int goalId) async {
    final item = await fetchItem(itemId);
    if (item.goals.any((goal) => goal.id == goalId)) {
      return;
    }
    _replace(
      KnowledgeItem(
        id: item.id,
        title: item.title,
        content: item.content,
        links: item.links,
        sensitivity: item.sensitivity,
        relations: item.relations,
        attachments: item.attachments,
        tags: item.tags,
        goals: [
          ...item.goals,
          KnowledgeGoalReference(id: goalId, title: 'Meta $goalId'),
        ],
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      ),
    );
  }

  @override
  Future<void> removeGoal(int itemId, int goalId) async {
    final item = await fetchItem(itemId);
    _replace(
      KnowledgeItem(
        id: item.id,
        title: item.title,
        content: item.content,
        links: item.links,
        sensitivity: item.sensitivity,
        relations: item.relations,
        attachments: item.attachments,
        tags: item.tags,
        goals: item.goals.where((goal) => goal.id != goalId).toList(),
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      ),
    );
  }

  @override
  Future<KnowledgeAttachment> uploadAttachment(
    int itemId,
    KnowledgeUploadFile file,
  ) async {
    final item = await fetchItem(itemId);
    final attachment = KnowledgeAttachment(
      id: _nextAttachmentId++,
      filename: file.filename,
      contentType: file.contentType,
      sizeBytes: file.bytes.length,
      downloadUrl: '/api/v1/knowledge/$itemId/attachments/1/download?token=t',
    );
    _replace(
      KnowledgeItem(
        id: item.id,
        title: item.title,
        content: item.content,
        links: item.links,
        sensitivity: item.sensitivity,
        relations: item.relations,
        attachments: [...item.attachments, attachment],
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      ),
    );
    return attachment;
  }

  @override
  Future<void> deleteAttachment(int itemId, int attachmentId) async {
    final item = await fetchItem(itemId);
    _replace(
      KnowledgeItem(
        id: item.id,
        title: item.title,
        content: item.content,
        links: item.links,
        sensitivity: item.sensitivity,
        relations: item.relations,
        attachments: item.attachments
            .where((attachment) => attachment.id != attachmentId)
            .toList(),
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      ),
    );
  }

  @override
  Future<KnowledgeObservation> addObservation(int itemId, String text) async {
    final item = await fetchItem(itemId);
    final observation = KnowledgeObservation(
      id: _nextObservationId++,
      text: text,
      createdAt: DateTime(2026, 10, 21, 9, 30),
    );
    _replace(
      KnowledgeItem(
        id: item.id,
        title: item.title,
        content: item.content,
        links: item.links,
        sensitivity: item.sensitivity,
        relations: item.relations,
        attachments: item.attachments,
        tags: item.tags,
        goals: item.goals,
        observations: [...item.observations, observation],
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      ),
    );
    return observation;
  }

  @override
  Future<void> deleteObservation(int itemId, int observationId) async {
    final item = await fetchItem(itemId);
    _replace(
      KnowledgeItem(
        id: item.id,
        title: item.title,
        content: item.content,
        links: item.links,
        sensitivity: item.sensitivity,
        relations: item.relations,
        attachments: item.attachments,
        tags: item.tags,
        goals: item.goals,
        observations: item.observations
            .where((observation) => observation.id != observationId)
            .toList(),
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      ),
    );
  }

  @override
  Uri attachmentDownloadUri(KnowledgeAttachment attachment) {
    return Uri.parse('https://example.test${attachment.downloadUrl}');
  }

  void _replace(KnowledgeItem item) {
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    _items[index] = item;
  }

  KnowledgeItem _withRelation(KnowledgeItem item, KnowledgeItem target) {
    if (item.relations.any((relation) => relation.id == target.id)) {
      return item;
    }
    return KnowledgeItem(
      id: item.id,
      title: item.title,
      content: item.content,
      links: item.links,
      sensitivity: item.sensitivity,
      relations: [
        ...item.relations,
        KnowledgeReference(id: target.id, title: target.title),
      ],
      attachments: item.attachments,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }

  KnowledgeItem _withoutRelation(KnowledgeItem item, int relationId) {
    return KnowledgeItem(
      id: item.id,
      title: item.title,
      content: item.content,
      links: item.links,
      sensitivity: item.sensitivity,
      relations: item.relations
          .where((relation) => relation.id != relationId)
          .toList(),
      attachments: item.attachments,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    );
  }
}
