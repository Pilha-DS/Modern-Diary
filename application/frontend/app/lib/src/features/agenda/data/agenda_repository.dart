// Mantém os nomes públicos dos parâmetros sem expor os campos privados.
// ignore_for_file: prefer_initializing_formals

import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_client.dart';
import '../domain/agenda_models.dart';

/// Contrato consumido pelo controller; permite testar sem HTTP.
abstract interface class AgendaDataSource {
  Future<List<AgendaDaySummary>> fetchSummaries({
    required DateTime from,
    required DateTime to,
  });

  Future<AgendaDay> fetchDay(DateTime day);

  Future<AgendaDay> addNote(
    DateTime day,
    String content, {
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  });

  Future<AgendaNote> updateNote(
    int noteId, {
    String? content,
    SensitivityLevel? sensitivity,
  });

  Future<void> deleteNote(int noteId);

  Future<AgendaDay> setDaySensitivity(
    DateTime day,
    SensitivityLevel sensitivity,
  );

  Future<AgendaActivity> createActivity({
    required DateTime day,
    required String title,
    String? startTime,
    required AgendaPriority priority,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  });

  Future<AgendaActivity> updateActivity(
    int activityId, {
    bool? isDone,
    String? title,
    String? startTime,
    bool clearStartTime = false,
    AgendaPriority? priority,
    SensitivityLevel? sensitivity,
  });

  Future<void> deleteActivity(int activityId);

  Future<AgendaDay> setDayTags(DateTime day, List<int> tagIds);
}

class AgendaRepository implements AgendaDataSource {
  AgendaRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<AgendaDaySummary>> fetchSummaries({
    required DateTime from,
    required DateTime to,
  }) async {
    final envelope = await _client.get(
      '/api/v1/agenda/summary',
      query: {'from': dateKey(from), 'to': dateKey(to)},
      parse: (data) {
        final list = data! as List;
        return list
            .whereType<Map>()
            .map(
              (item) =>
                  AgendaDaySummary.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      },
    );

    return envelope.data ?? const [];
  }

  @override
  Future<AgendaDay> fetchDay(DateTime day) async {
    final envelope = await _client.get(
      '/api/v1/agenda/days/${dateKey(day)}',
      parse: _parseDay,
    );
    return envelope.data!;
  }

  @override
  Future<AgendaDay> addNote(
    DateTime day,
    String content, {
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    final envelope = await _client.post(
      '/api/v1/agenda/days/${dateKey(day)}/notes',
      body: {'content': content, 'sensitivity': sensitivity.apiValue},
      parse: _parseDay,
    );
    return envelope.data!;
  }

  @override
  Future<AgendaNote> updateNote(
    int noteId, {
    String? content,
    SensitivityLevel? sensitivity,
  }) async {
    final body = <String, Object?>{};
    if (content != null) {
      body['content'] = content;
    }
    if (sensitivity != null) {
      body['sensitivity'] = sensitivity.apiValue;
    }

    final envelope = await _client.patch(
      '/api/v1/agenda/notes/$noteId',
      body: body,
      parse: (data) =>
          AgendaNote.fromJson(Map<String, dynamic>.from(data! as Map)),
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteNote(int noteId) async {
    await _client.delete('/api/v1/agenda/notes/$noteId', parse: (_) {});
  }

  @override
  Future<AgendaDay> setDaySensitivity(
    DateTime day,
    SensitivityLevel sensitivity,
  ) async {
    final envelope = await _client.put(
      '/api/v1/agenda/days/${dateKey(day)}/sensitivity',
      body: {'sensitivity': sensitivity.apiValue},
      parse: _parseDay,
    );
    return envelope.data!;
  }

  @override
  Future<AgendaActivity> createActivity({
    required DateTime day,
    required String title,
    String? startTime,
    required AgendaPriority priority,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    final envelope = await _client.post(
      '/api/v1/agenda/days/${dateKey(day)}/activities',
      body: {
        'title': title,
        'start_time': startTime,
        'priority': priority.apiValue,
        'sensitivity': sensitivity.apiValue,
      },
      parse: (data) =>
          AgendaActivity.fromJson(Map<String, dynamic>.from(data! as Map)),
    );
    return envelope.data!;
  }

  @override
  Future<AgendaActivity> updateActivity(
    int activityId, {
    bool? isDone,
    String? title,
    String? startTime,
    bool clearStartTime = false,
    AgendaPriority? priority,
    SensitivityLevel? sensitivity,
  }) async {
    final body = <String, Object?>{};
    if (title != null) {
      body['title'] = title;
    }
    if (priority != null) {
      body['priority'] = priority.apiValue;
    }
    if (isDone != null) {
      body['is_done'] = isDone;
    }
    if (clearStartTime) {
      body['start_time'] = null;
    } else if (startTime != null) {
      body['start_time'] = startTime;
    }
    if (sensitivity != null) {
      body['sensitivity'] = sensitivity.apiValue;
    }

    final envelope = await _client.patch(
      '/api/v1/agenda/activities/$activityId',
      body: body,
      parse: (data) =>
          AgendaActivity.fromJson(Map<String, dynamic>.from(data! as Map)),
    );
    return envelope.data!;
  }

  @override
  Future<void> deleteActivity(int activityId) async {
    await _client.delete(
      '/api/v1/agenda/activities/$activityId',
      parse: (_) {},
    );
  }

  @override
  Future<AgendaDay> setDayTags(DateTime day, List<int> tagIds) async {
    final envelope = await _client.put(
      '/api/v1/agenda/days/${dateKey(day)}/tags',
      body: {'tag_ids': tagIds},
      parse: _parseDay,
    );
    return envelope.data!;
  }

  AgendaDay _parseDay(Object? data) {
    return AgendaDay.fromJson(Map<String, dynamic>.from(data! as Map));
  }
}
