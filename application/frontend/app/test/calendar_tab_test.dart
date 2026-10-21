import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/agenda/data/agenda_repository.dart';
import 'package:modern_diary/src/features/agenda/domain/agenda_models.dart';
import 'package:modern_diary/src/features/agenda/presentation/agenda_controller.dart';
import 'package:modern_diary/src/features/agenda/presentation/calendar_tab.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import 'support/fake_tags_data_source.dart';

class _FakeAgendaDataSource implements AgendaDataSource {
  _FakeAgendaDataSource({required this.today, this.holiday});

  final DateTime today;
  final String? holiday;

  @override
  Future<List<AgendaDaySummary>> fetchSummaries({
    required DateTime from,
    required DateTime to,
  }) async {
    final name = holiday;
    if (name == null) {
      return const [];
    }
    return [
      AgendaDaySummary(
        day: DateTime(today.year, today.month, 20),
        hasNote: false,
        activitiesTotal: 0,
        activitiesDone: 0,
        holiday: name,
      ),
    ];
  }

  @override
  Future<AgendaDay> fetchDay(DateTime day) async {
    return AgendaDay(
      day: day,
      activities: const [],
      holiday: day.day == 20 ? holiday : null,
    );
  }

  @override
  Future<AgendaDay> addNote(
    DateTime day,
    String content, {
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    return fetchDay(day);
  }

  @override
  Future<AgendaNote> updateNote(
    int noteId, {
    String? content,
    SensitivityLevel? sensitivity,
  }) async {
    return AgendaNote(
      id: noteId,
      content: content ?? '',
      sensitivity: sensitivity ?? SensitivityLevel.publico,
    );
  }

  @override
  Future<void> deleteNote(int noteId) async {}

  @override
  Future<AgendaDay> setDaySensitivity(
    DateTime day,
    SensitivityLevel sensitivity,
  ) async {
    return fetchDay(day);
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

void main() {
  final today = DateTime(2026, 10, 19);

  testWidgets('mostra os doze meses sem o painel grande do dia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = AgendaController(
      _FakeAgendaDataSource(today: today),
      clock: () => today,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final toat = ToatController();
    addTearDown(toat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: SingleChildScrollView(
            child: CalendarTab(
              controller: controller,
              tagsDataSource: FakeTagsDataSource(),
              toat: toat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final month in AppStrings.monthNames) {
      expect(find.text(month), findsOneWidget);
    }
    expect(find.text(AppStrings.noteTitle), findsNothing);
  });

  testWidgets('clicar em um dia abre o dia em modal', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final handle = tester.ensureSemantics();

    final controller = AgendaController(
      _FakeAgendaDataSource(today: today),
      clock: () => today,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final toat = ToatController();
    addTearDown(toat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: SingleChildScrollView(
            child: CalendarTab(
              controller: controller,
              tagsDataSource: FakeTagsDataSource(),
              toat: toat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('20 de Outubro'));
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.dayTitle(DateTime(2026, 10, 20))),
      findsOneWidget,
    );
    expect(find.text(AppStrings.noteTitle), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.close));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.noteTitle), findsNothing);
    handle.dispose();
  });

  testWidgets('hover no dia com conteúdo abre a prévia ao lado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const holiday = 'Nossa Senhora Aparecida';
    final controller = AgendaController(
      _FakeAgendaDataSource(today: today, holiday: holiday),
      clock: () => today,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final toat = ToatController();
    addTearDown(toat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: SingleChildScrollView(
            child: CalendarTab(
              controller: controller,
              tagsDataSource: FakeTagsDataSource(),
              toat: toat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final october = find.byWidgetPredicate(
      (widget) => widget is MonthCalendar && widget.month == 10,
    );
    final day20 = find.descendant(of: october, matching: find.text('20'));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(day20));
    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();

    // A prévia mostra as informações do dia, não apenas a contagem.
    expect(find.text(holiday), findsOneWidget);
    expect(find.text(AppStrings.dayPreviewNoActivities), findsOneWidget);
    expect(find.text(AppStrings.daySensitivityNone), findsOneWidget);
  });

  testWidgets('feriado fica laranja no calendário e vira status no dia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final handle = tester.ensureSemantics();
    const holiday = 'Nossa Senhora Aparecida';
    final controller = AgendaController(
      _FakeAgendaDataSource(today: today, holiday: holiday),
      clock: () => today,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    final toat = ToatController();
    addTearDown(toat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: SingleChildScrollView(
            child: CalendarTab(
              controller: controller,
              tagsDataSource: FakeTagsDataSource(),
              toat: toat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final october = find.byWidgetPredicate(
      (widget) => widget is MonthCalendar && widget.month == 10,
    );
    final day20 = find.descendant(of: october, matching: find.text('20'));
    final container = tester.widget<AnimatedContainer>(
      find.ancestor(of: day20, matching: find.byType(AnimatedContainer)),
    );
    final semanticColors = AppSemanticColors.of(
      tester.element(find.byType(CalendarTab)),
    );

    expect(
      (container.decoration as BoxDecoration?)?.color,
      semanticColors.holidaySoft,
    );
    expect(
      find.bySemanticsLabel(
        AppStrings.daySemantics(
          DateTime(2026, 10, 20),
          hasNote: false,
          holiday: holiday,
        ),
      ),
      findsWidgets,
    );

    await tester.tap(day20);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.holidayStatus(holiday)), findsOneWidget);
    expect(find.text(AppStrings.noteTitle), findsOneWidget);

    handle.dispose();
  });
}
