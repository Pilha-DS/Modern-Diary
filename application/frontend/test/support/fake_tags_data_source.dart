import 'package:modern_diary/src/features/tags/data/tags_repository.dart';
import 'package:modern_diary/src/features/tags/domain/tag_models.dart';

/// Implementação em memória para testar telas sem HTTP.
class FakeTagsDataSource implements TagsDataSource {
  FakeTagsDataSource({
    List<Tag> initial = const [],
    List<TagUsage> usages = const [],
  }) : _usages = [...usages] {
    _tags.addAll(initial);
    _nextId = _tags.fold(0, (max, tag) => tag.id > max ? tag.id : max) + 1;
  }

  final List<Tag> _tags = [];
  final List<TagUsage> _usages;
  late int _nextId;

  List<Tag> get tags => List.unmodifiable(_tags);

  @override
  Future<TagPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
  }) async {
    final size = perPage ?? 20;
    final cleaned = query?.trim().toLowerCase() ?? '';
    final matches = cleaned.isEmpty
        ? _tags
        : _tags
              .where((tag) => tag.name.toLowerCase().contains(cleaned))
              .toList();
    final offset = (page - 1) * size;

    return TagPage(
      tags: matches.skip(offset).take(size).toList(),
      page: page,
      perPage: size,
      total: matches.length,
      totalPages: (matches.length / size).ceil(),
    );
  }

  @override
  Future<Tag> createTag({
    required String name,
    required String colorHex,
    String? description,
  }) async {
    final tag = Tag(
      id: _nextId++,
      name: name,
      colorHex: colorHex,
      description: description,
      usageCount: 0,
    );
    _tags.add(tag);
    return tag;
  }

  @override
  Future<Tag> updateTag(
    int tagId, {
    String? name,
    String? colorHex,
    String? description,
    bool? changeDescription,
  }) async {
    final current = _tags.firstWhere((tag) => tag.id == tagId);
    final updated = current.copyWith(
      name: name ?? current.name,
      colorHex: colorHex ?? current.colorHex,
      description: (changeDescription ?? false)
          ? description
          : current.description,
    );
    final index = _tags.indexWhere((tag) => tag.id == tagId);
    _tags[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteTag(int tagId) async {
    _tags.removeWhere((tag) => tag.id == tagId);
  }

  @override
  Future<TagUsagePage> fetchUsages(
    int tagId, {
    required int page,
    int? perPage,
  }) async {
    final size = perPage ?? 20;
    final offset = (page - 1) * size;
    return TagUsagePage(
      usages: _usages.skip(offset).take(size).toList(),
      page: page,
      total: _usages.length,
      totalPages: (_usages.length / size).ceil(),
    );
  }
}
