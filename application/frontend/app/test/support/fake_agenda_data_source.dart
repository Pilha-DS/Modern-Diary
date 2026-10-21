import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/features/agenda/data/agenda_repository.dart';
import 'package:modern_diary/src/features/agenda/domain/agenda_models.dart';

/// Agenda em memória, sem HTTP, para testar telas que dependem do dia.
class FakeAgendaDataSource implements AgendaDataSource {
  FakeAgendaDataSource({required this.today, String? note})
    : notes = note == null
          ? const []
          : [
              AgendaNote(
                id: 1,
                content: note,
                sensitivity: SensitivityLevel.publico,
              ),
            ];

  final DateTime today;
  final List<AgendaNote> notes;
  int nextNoteId = 2;

  @override
  Future<List<AgendaDaySummary>> fetchSummaries({
    required DateTime from,
    required DateTime to,
  }) async {
    return [
      AgendaDaySummary(
        day: today,
        hasNote: notes.isNotEmpty,
        activitiesTotal: 0,
        activitiesDone: 0,
      ),
    ];
  }

  @override
  Future<AgendaDay> fetchDay(DateTime day) async {
    return AgendaDay(day: day, activities: const [], notes: notes);
  }

  @override
  Future<AgendaDay> addNote(
    DateTime day,
    String content, {
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    notes.add(
      AgendaNote(id: nextNoteId++, content: content, sensitivity: sensitivity),
    );
    return fetchDay(day);
  }

  @override
  Future<AgendaNote> updateNote(
    int noteId, {
    String? content,
    SensitivityLevel? sensitivity,
  }) async {
    final index = notes.indexWhere((note) => note.id == noteId);
    final note = AgendaNote(
      id: noteId,
      content: content ?? notes[index].content,
      sensitivity: sensitivity ?? notes[index].sensitivity,
    );
    if (index >= 0) {
      notes[index] = note;
    }
    return note;
  }

  @override
  Future<void> deleteNote(int noteId) async {
    notes.removeWhere((note) => note.id == noteId);
  }

  @override
  Future<AgendaDay> setDaySensitivity(
    DateTime day,
    SensitivityLevel sensitivity,
  ) async {
    return AgendaDay(
      day: day,
      activities: const [],
      notes: notes,
      sensitivity: sensitivity,
    );
  }

  @override
  Future<AgendaActivity> createActivity({
    required DateTime day,
    required String title,
    String? startTime,
    required AgendaPriority priority,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    return AgendaActivity(
      id: 1,
      title: title,
      startTime: startTime,
      priority: priority,
      isDone: false,
      sensitivity: sensitivity,
    );
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
    return AgendaActivity(
      id: activityId,
      title: title ?? '',
      startTime: startTime,
      priority: priority ?? AgendaPriority.medium,
      isDone: isDone ?? false,
      sensitivity: sensitivity ?? SensitivityLevel.publico,
    );
  }

  @override
  Future<void> deleteActivity(int activityId) async {}

  @override
  Future<AgendaDay> setDayTags(DateTime day, List<int> tagIds) async {
    return fetchDay(day);
  }
}
