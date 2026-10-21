import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/features/notes/data/notes_repository.dart';
import 'package:modern_diary/src/features/notes/domain/note_models.dart';
import 'package:modern_diary/src/features/notes/presentation/notes_controller.dart';

import 'support/fake_notes_data_source.dart';

Note _note(
  int id, {
  String? title,
  String content = 'Conteúdo',
  bool isPinned = false,
}) {
  return Note(
    id: id,
    title: title ?? 'Nota $id',
    content: content,
    isPinned: isPinned,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  );
}

NotesPage _page(int id, String title) {
  return NotesPage(
    items: [
      NoteSummary(
        id: id,
        title: title,
        preview: 'Conteúdo',
        isPinned: false,
        sensitivity: SensitivityLevel.publico,
        createdAt: DateTime(2026, 10, 20),
        updatedAt: DateTime(2026, 10, 20),
      ),
    ],
    page: 1,
    perPage: 12,
    total: 1,
    totalPages: 1,
  );
}

/// Segura cada resposta até o teste liberar, para simular rede lenta.
class _DelayedNotesDataSource implements NotesDataSource {
  final List<Completer<NotesPage>> pending = [];
  final List<String?> queries = [];

  @override
  Future<NotesPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
    bool? pinned,
  }) {
    queries.add(query);
    final completer = Completer<NotesPage>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<Note> fetchNote(int noteId) => throw UnimplementedError();

  @override
  Future<Note> createNote({
    String? title,
    required String content,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) => throw UnimplementedError();

  @override
  Future<Note> updateNote(
    int noteId, {
    String? title,
    bool? changeTitle,
    String? content,
    bool? isPinned,
    SensitivityLevel? sensitivity,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteNote(int noteId) => throw UnimplementedError();
}

void main() {
  test('carrega a primeira página e busca as próximas sob demanda', () async {
    final source = FakeNotesDataSource(
      initial: [for (var id = 1; id <= 13; id++) _note(id)],
    );
    final controller = NotesController(source);
    addTearDown(controller.dispose);

    await controller.loadFirstPage();

    expect(controller.items.length, 12);
    expect(controller.total, 13);
    expect(controller.hasMore, isTrue);

    await controller.loadMore();

    expect(controller.items.length, 13);
    expect(controller.hasMore, isFalse);
  });

  test('busca e filtro de fixadas vão para o back', () async {
    final source = FakeNotesDataSource(
      initial: [
        _note(1, title: 'Receita', content: 'Farinha'),
        _note(2, title: 'Ideias', content: 'Comprar farinha', isPinned: true),
      ],
    );
    final controller = NotesController(source);
    addTearDown(controller.dispose);
    await controller.loadFirstPage();

    await controller.setQuery('farinha');

    expect(source.lastQuery, 'farinha');
    expect(controller.items.length, 2);

    await controller.setPinned(true);

    expect(source.lastPinned, isTrue);
    expect(controller.items.single.title, 'Ideias');
  });

  test('limpar os filtros faz uma única requisição', () async {
    final source = FakeNotesDataSource(initial: [_note(1)]);
    final controller = NotesController(source);
    addTearDown(controller.dispose);
    await controller.loadFirstPage();
    await controller.setQuery('nota');
    await controller.setPinned(true);

    final before = source.fetchCalls;
    await controller.clearFilters();

    expect(source.fetchCalls, before + 1);
    expect(controller.query, isEmpty);
    expect(controller.pinned, isNull);
  });

  test('cria, edita, fixa e exclui nota', () async {
    final source = FakeNotesDataSource();
    final controller = NotesController(source);
    addTearDown(controller.dispose);
    await controller.loadFirstPage();

    final createError = await controller.createNote(
      content: '# Ideia\n\nPrimeira linha',
    );

    expect(createError, isNull);
    expect(controller.items.single.title, isNull);

    final id = controller.items.single.id;
    final updateError = await controller.updateNote(
      id,
      title: 'Projeto',
      content: 'Texto novo',
    );

    expect(updateError, isNull);
    expect(controller.items.single.title, 'Projeto');
    expect(controller.items.single.preview, 'Texto novo');

    await controller.togglePin(controller.items.single);

    expect(controller.items.single.isPinned, isTrue);

    final deleteError = await controller.deleteNote(id);

    expect(deleteError, isNull);
    expect(controller.items, isEmpty);
  });

  test('a resposta de uma busca antiga não sobrescreve a atual', () async {
    final source = _DelayedNotesDataSource();
    final controller = NotesController(source);
    addTearDown(controller.dispose);

    final first = controller.loadFirstPage();
    final search = controller.setQuery('farinha');

    expect(source.queries, ['', 'farinha']);

    source.pending[1].complete(_page(2, 'Receita'));
    await search;
    source.pending[0].complete(_page(1, 'Antiga'));
    await first;

    expect(controller.items.single.title, 'Receita');
    expect(controller.isLoading, isFalse);
  });
}
