import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/agenda/domain/agenda_models.dart';
import 'package:modern_diary/src/features/agenda/presentation/agenda_controller.dart';
import 'package:modern_diary/src/features/agenda/presentation/day_panel.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import 'support/fake_agenda_data_source.dart';
import 'support/fake_tags_data_source.dart';

/// Guarda o que o formulário enviou, já que o back falso não persiste.
class _RecordingAgendaDataSource extends FakeAgendaDataSource {
  _RecordingAgendaDataSource({required super.today});

  String? createdStartTime;

  @override
  Future<AgendaActivity> createActivity({
    required DateTime day,
    required String title,
    String? startTime,
    required AgendaPriority priority,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    createdStartTime = startTime;
    return super.createActivity(
      day: day,
      title: title,
      startTime: startTime,
      priority: priority,
      sensitivity: sensitivity,
    );
  }
}

void main() {
  final today = DateTime(2026, 10, 21);

  Future<(AgendaController, _RecordingAgendaDataSource, ToatController)>
  pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final source = _RecordingAgendaDataSource(today: today);
    final controller = AgendaController(source, clock: () => today);
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
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DayPanel(
              controller: controller,
              tagsDataSource: FakeTagsDataSource(),
              toat: toat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (controller, source, toat);
  }

  Future<void> openForm(WidgetTester tester) async {
    // O dia abre em leitura: as ações do dia só aparecem no modo de edição.
    await tester.tap(find.text(AppStrings.editDay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.newActivity));
    await tester.pumpAndSettle();
  }

  Future<void> fillTitle(WidgetTester tester, String title) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      title,
    );
  }

  /// Centro da posição de [value] na órbita do relógio [dialIndex].
  Offset dialPosition(
    WidgetTester tester,
    int dialIndex,
    int count,
    int value,
  ) {
    final rect = tester.getRect(find.byType(AppClockDial).at(dialIndex));
    final radius = rect.width / 2 - 20;
    final angle = -math.pi / 2 + 2 * math.pi * value / count;
    return rect.center +
        Offset(radius * 0.9 * math.cos(angle), radius * 0.9 * math.sin(angle));
  }

  /// Fecha as notificações para não deixar o timer do TOAT pendente.
  Future<void> dismissToats(WidgetTester tester, ToatController toat) async {
    for (final message in [...toat.messages]) {
      toat.dismiss(message.id);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('o horário da atividade não é digitável', (tester) async {
    await pumpPanel(tester);
    await openForm(tester);

    expect(find.text(AppStrings.activityTimePlaceholder), findsOneWidget);
    // Só o título é campo de texto: a hora é escolhida no relógio.
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
  });

  testWidgets('escolhe hora e minuto no relógio e envia o horário', (
    tester,
  ) async {
    final (_, source, toat) = await pumpPanel(tester);
    await openForm(tester);
    await fillTitle(tester, 'Estudar');

    await tester.tap(find.text(AppStrings.activityTimePlaceholder));
    await tester.pumpAndSettle();

    expect(find.byType(AppClockDial), findsNWidgets(2));

    // 21 h no relógio das horas e 45 min no dos minutos.
    await tester.tapAt(dialPosition(tester, 0, 24, 21));
    await tester.pumpAndSettle();
    await tester.tapAt(dialPosition(tester, 1, 60, 45));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.timePickerConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(AppClockDial), findsNothing);
    expect(find.text('21:45'), findsOneWidget);

    await tester.tap(find.text(AppStrings.createActivity));
    await tester.pumpAndSettle();

    expect(source.createdStartTime, '21:45');
    await dismissToats(tester, toat);
  });

  testWidgets('sem escolher horário, a atividade é criada sem hora', (
    tester,
  ) async {
    final (_, source, toat) = await pumpPanel(tester);
    await openForm(tester);
    await fillTitle(tester, 'Caminhar');

    await tester.tap(find.text(AppStrings.createActivity));
    await tester.pumpAndSettle();

    expect(source.createdStartTime, isNull);
    await dismissToats(tester, toat);
  });

  testWidgets('o botão de limpar remove o horário escolhido', (tester) async {
    await pumpPanel(tester);
    await openForm(tester);
    await fillTitle(tester, 'Ler');

    await tester.tap(find.text(AppStrings.activityTimePlaceholder));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.timePickerConfirm));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.activityTimePlaceholder), findsNothing);

    await tester.tap(find.byTooltip(AppStrings.activityTimeClear));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.activityTimePlaceholder), findsOneWidget);
  });
}
