import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json_values.dart';
import '../domain/note_models.dart';

/// Contrato consumido pelo controller; permite testar sem HTTP.
abstract interface class NotesDataSource {
  Future<NotesPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
    bool? pinned,
  });

  Future<Note> fetchNote(int noteId);

  Future<Note> createNote({
    String? title,
    required String content,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  });

  Future<Note> updateNote(
    int noteId, {
    String? title,
    bool? changeTitle,
    String? content,
    bool? isPinned,
    SensitivityLevel? sensitivity,
  });

  Future<void> deleteNote(int noteId);
}

class NotesRepository implements NotesDataSource {
  NotesRepository(this._client);

  final ApiClient _client;

  static const int pageSize = 12;

  @override
  Future<NotesPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
    bool? pinned,
  }) async {
    final requested = perPage ?? pageSize;
    final envelope = await _client.get(
      '/api/v1/notes',
      query: {
        'page': '$page',
        'per_page': '$requested',
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (pinned != null) 'pinned': '$pinned',
      },
      parse: _parseItems,
    );
    final meta = envelope.meta;

    return NotesPage(
      items: envelope.data ?? const [],
      page: readInt(meta['page'], fallback: page),
      perPage: readInt(meta['per_page'], fallback: requested),
      total: readInt(meta['total']),
      totalPages: readInt(meta['total_pages']),
    );
  }

  @override
  Future<Note> fetchNote(int noteId) async {
    final envelope = await _client.get(
      '/api/v1/notes/$noteId',
      parse: _parseNote,
    );
    return envelope.data!;
  }

  @override
  Future<Note> createNote({
    String? title,
    required String content,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    final envelope = await _client.post(
      '/api/v1/notes',
      body: {
        'title': title,
        'content': content,
        'sensitivity': sensitivity.apiValue,
      },
      parse: _parseNote,
    );
    return envelope.data!;
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
    final body = <String, Object?>{};
    if (changeTitle ?? false) {
      body['title'] = title;
    }
    if (content != null) {
      body['content'] = content;
    }
    if (isPinned != null) {
      body['is_pinned'] = isPinned;
    }
    if (sensitivity != null) {
      body['sensitivity'] = sensitivity.apiValue;
    }

    final envelope = await _client.patch(
      '/api/v1/notes/$noteId',
      body: body,
      parse: _parseNote,
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteNote(int noteId) async {
    await _client.delete('/api/v1/notes/$noteId', parse: (_) {});
  }

  Note _parseNote(Object? data) {
    return Note.fromJson(Map<String, dynamic>.from(data! as Map));
  }

  List<NoteSummary> _parseItems(Object? data) {
    final list = data! as List;
    return list
        .whereType<Map>()
        .map((item) => NoteSummary.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}
