import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/features/agenda/data/agenda_repository.dart';
import 'package:modern_diary/src/features/agenda/domain/agenda_models.dart';
import 'package:modern_diary/src/features/agenda/presentation/agenda_controller.dart';

class _FakeAgendaDataSource implements AgendaDataSource {
  _FakeAgendaDataSource({required this.today});

  final DateTime today;
  final Map<String, AgendaDay> days = {};
  final Map<String, AgendaDaySummary> summaries = {};
  int updateCalls = 0;
  int nextNoteId = 1;

  @override
  Future<List<AgendaDaySummary>> fetchSummaries({
    required DateTime from,
    required DateTime to,
  }) async {
    return summaries.values
        .where(
          (summary) => !summary.day.isBefore(from) && !summary.day.isAfter(to),
        )
        .toList();
  }

  @override
  Future<AgendaDay> fetchDay(DateTime day) async {
    return days[dateKey(day)] ?? AgendaDay(day: day, activities: const []);
  }

  Future<AgendaDay> _store(AgendaDay day) async {
    days[dateKey(day.day)] = day;
    summaries[dateKey(day.day)] = AgendaDaySummary(
      day: day.day,
      hasNote: day.notes.isNotEmpty,
      activitiesTotal: day.activities.length,
      activitiesDone: day.doneCount,
    );
    return day;
  }

  @override
  Future<AgendaDay> addNote(
    DateTime day,
    String content, {
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    final existing = await fetchDay(day);
    return _store(
      AgendaDay(
        day: day,
        notes: [
          ...existing.notes,
          AgendaNote(
            id: nextNoteId++,
            content: content,
            sensitivity: sensitivity,
          ),
        ],
        sensitivity: existing.sensitivity,
        activities: existing.activities,
      ),
    );
  }

  @override
  Future<AgendaNote> updateNote(
    int noteId, {
    String? content,
    SensitivityLevel? sensitivity,
  }) async {
    final day = await fetchDay(today);
    late AgendaNote changed;
    final notes = day.notes.map((note) {
      if (note.id != noteId) {
        return note;
      }
      changed = AgendaNote(
        id: note.id,
        content: content ?? note.content,
        sensitivity: sensitivity ?? note.sensitivity,
      );
      return changed;
    }).toList();
    await _store(
      AgendaDay(
        day: today,
        notes: notes,
        sensitivity: day.sensitivity,
        activities: day.activities,
      ),
    );
    return changed;
  }

  @override
  Future<void> deleteNote(int noteId) async {
    final day = await fetchDay(today);
    await _store(
      AgendaDay(
        day: today,
        notes: [
          for (final note in day.notes)
            if (note.id != noteId) note,
        ],
        sensitivity: day.sensitivity,
        activities: day.activities,
      ),
    );
  }

  @override
  Future<AgendaDay> setDaySensitivity(
    DateTime day,
    SensitivityLevel sensitivity,
  ) async {
    final existing = await fetchDay(day);
    return _store(
      AgendaDay(
        day: day,
        notes: existing.notes,
        sensitivity: sensitivity,
        activities: existing.activities,
      ),
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
    final existing = await fetchDay(day);
    final activity = AgendaActivity(
      id: existing.activities.length + 1,
      title: title,
      startTime: startTime,
      priority: priority,
      isDone: false,
      sensitivity: sensitivity,
    );
    await _store(
      AgendaDay(
        day: day,
        notes: existing.notes,
        sensitivity: existing.sensitivity,
        activities: [...existing.activities, activity],
      ),
    );
    return activity;
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
    updateCalls++;
    final day = await fetchDay(today);
    late AgendaActivity changed;
    final activities = day.activities.map((activity) {
      if (activity.id != activityId) {
        return activity;
      }
      changed = AgendaActivity(
        id: activity.id,
        title: title ?? activity.title,
        startTime: clearStartTime ? null : (startTime ?? activity.startTime),
        priority: priority ?? activity.priority,
        isDone: isDone ?? activity.isDone,
        sensitivity: sensitivity ?? activity.sensitivity,
      );
      return changed;
    }).toList();
    await _store(
      AgendaDay(
        day: today,
        notes: day.notes,
        sensitivity: day.sensitivity,
        activities: activities,
      ),
    );
    return changed;
  }

  @override
  Future<void> deleteActivity(int activityId) async {
    updateCalls++;
  }

  @override
  Future<AgendaDay> setDayTags(DateTime day, List<int> tagIds) async {
    updateCalls++;
    return fetchDay(day);
  }
}

void main() {
  final today = DateTime(2026, 10, 19);

  test('carrega o ano e o dia atual', () async {
    final source = _FakeAgendaDataSource(today: today);
    source.summaries[dateKey(today)] = AgendaDaySummary(
      day: today,
      hasNote: true,
      activitiesTotal: 0,
      activitiesDone: 0,
    );
    source.days[dateKey(today)] = AgendaDay(
      day: today,
      notes: const [
        AgendaNote(
          id: 1,
          content: 'Nota',
          sensitivity: SensitivityLevel.publico,
        ),
      ],
      activities: const [],
    );

    final controller = AgendaController(source, clock: () => today);
    await controller.initialize();

    expect(controller.summaries.length, 1);
    expect(controller.day?.notes.single.content, 'Nota');
    expect(controller.selectedDay, today);
    expect(controller.isYearLoadedFor(today.year), isTrue);
    controller.dispose();
  });

  test('cria nota, atualiza o nível e remove', () async {
    final source = _FakeAgendaDataSource(today: today);
    final controller = AgendaController(source, clock: () => today);
    await controller.initialize();

    expect(
      await controller.addNote(
        '# Hoje',
        sensitivity: SensitivityLevel.moderado,
      ),
      isNull,
    );
    expect(controller.day?.notes.single.content, '# Hoje');
    expect(controller.summaryFor(today)?.hasNote, isTrue);

    final note = controller.day!.notes.single;
    expect(
      await controller.updateNote(
        note.id,
        sensitivity: SensitivityLevel.basico,
      ),
      isNull,
    );
    expect(controller.day?.notes.single.sensitivity, SensitivityLevel.basico);

    expect(await controller.deleteNote(note.id), isNull);
    expect(controller.day?.notes, isEmpty);
    expect(controller.summaryFor(today)?.hasNote, isFalse);
    controller.dispose();
  });

  test('define o nível do dia', () async {
    final source = _FakeAgendaDataSource(today: today);
    final controller = AgendaController(source, clock: () => today);
    await controller.initialize();

    expect(
      await controller.setDaySensitivity(SensitivityLevel.sigiloso),
      isNull,
    );
    expect(controller.day?.sensitivity, SensitivityLevel.sigiloso);
    controller.dispose();
  });

  test('cria atividade e alterna a conclusão', () async {
    final source = _FakeAgendaDataSource(today: today);
    final controller = AgendaController(source, clock: () => today);
    await controller.initialize();

    expect(
      await controller.addActivity(
        title: 'Estudar',
        priority: AgendaPriority.high,
      ),
      isNull,
    );
    final activity = controller.day!.activities.single;
    expect(activity.title, 'Estudar');
    expect(controller.summaryFor(today)?.activitiesTotal, 1);

    expect(await controller.toggleActivity(activity), isNull);
    expect(controller.day!.activities.single.isDone, isTrue);
    expect(controller.summaryFor(today)?.activitiesDone, 1);
    controller.dispose();
  });

  test('seleciona outro dia e carrega o detalhe', () async {
    final source = _FakeAgendaDataSource(today: today);
    final otherDay = DateTime(2026, 10, 20);
    source.days[dateKey(otherDay)] = AgendaDay(
      day: otherDay,
      notes: const [
        AgendaNote(
          id: 2,
          content: 'Outro dia',
          sensitivity: SensitivityLevel.publico,
        ),
      ],
      activities: const [],
    );

    final controller = AgendaController(source, clock: () => today);
    await controller.initialize();
    await controller.selectDay(otherDay);

    expect(controller.selectedDay, otherDay);
    expect(controller.day?.notes.single.content, 'Outro dia');
    controller.dispose();
  });
}
