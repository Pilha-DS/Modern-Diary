import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/features/notes/data/notes_repository.dart';
import 'package:modern_diary/src/features/notes/domain/note_models.dart';

/// Implementação em memória com a mesma regra do back, para testar sem HTTP.
class FakeNotesDataSource implements NotesDataSource {
  FakeNotesDataSource({List<Note> initial = const []}) {
    _notes.addAll(initial);
    _nextId = _notes.fold(0, (max, note) => note.id > max ? note.id : max) + 1;
  }

  final List<Note> _notes = [];
  late int _nextId;
  int fetchCalls = 0;
  String? lastQuery;
  bool? lastPinned;

  List<Note> get notes => List.unmodifiable(_notes);

  @override
  Future<NotesPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
    bool? pinned,
  }) async {
    fetchCalls++;
    lastQuery = query;
    lastPinned = pinned;
    final term = (query ?? '').trim().toLowerCase();
    final filtered =
        _notes.where((note) {
          final matchesQuery =
              term.isEmpty ||
              (note.title?.toLowerCase().contains(term) ?? false) ||
              note.content.toLowerCase().contains(term);
          final matchesPinned = pinned == null || note.isPinned == pinned;
          return matchesQuery && matchesPinned;
        }).toList()..sort((first, second) {
          if (first.isPinned != second.isPinned) {
            return first.isPinned ? -1 : 1;
          }
          return second.updatedAt.compareTo(first.updatedAt);
        });

    final size = perPage ?? 12;
    final offset = (page - 1) * size;
    return NotesPage(
      items: filtered.skip(offset).take(size).map(_summaryOf).toList(),
      page: page,
      perPage: size,
      total: filtered.length,
      totalPages: (filtered.length / size).ceil(),
    );
  }

  @override
  Future<Note> fetchNote(int noteId) async {
    return _notes.firstWhere((note) => note.id == noteId);
  }

  @override
  Future<Note> createNote({
    String? title,
    required String content,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    final note = Note(
      id: _nextId++,
      title: title,
      content: content,
      sensitivity: sensitivity,
      isPinned: false,
      createdAt: DateTime(2026, 10, 20),
      updatedAt: DateTime(2026, 10, 20),
    );
    _notes.insert(0, note);
    return note;
  }

  @override
  Future<Note> updateNote(
    int noteId, {
    String? title,
    bool? changeTitle,
    String? content,
    bool? isPinned,
    SensitivityLevel? sensitivity,
  }) async {
    final current = await fetchNote(noteId);
    final updated = Note(
      id: current.id,
      title: (changeTitle ?? false) ? title : current.title,
      content: content ?? current.content,
      isPinned: isPinned ?? current.isPinned,
      sensitivity: sensitivity ?? current.sensitivity,
      createdAt: current.createdAt,
      updatedAt: DateTime(2026, 10, 21),
    );
    final index = _notes.indexWhere((note) => note.id == noteId);
    _notes[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteNote(int noteId) async {
    _notes.removeWhere((note) => note.id == noteId);
  }

  NoteSummary _summaryOf(Note note) {
    return NoteSummary(
      id: note.id,
      title: note.title,
      preview: note.content.length > 280
          ? note.content.substring(0, 280)
          : note.content,
      isPinned: note.isPinned,
      sensitivity: note.sensitivity,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
    );
  }
}
