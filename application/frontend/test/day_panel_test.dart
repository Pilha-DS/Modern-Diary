import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/agenda/presentation/agenda_controller.dart';
import 'package:modern_diary/src/features/agenda/presentation/day_panel.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_agenda_data_source.dart';
import 'support/fake_tags_data_source.dart';

void main() {
  final today = DateTime(2026, 10, 21);

  Future<(AgendaController, ToatController)> pumpPanel(
    WidgetTester tester, {
    String? note,
  }) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final source = FakeAgendaDataSource(today: today, note: note);
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
    return (controller, toat);
  }

  testWidgets('o dia abre em leitura e as ações só aparecem em Editar', (
    tester,
  ) async {
    await pumpPanel(tester, note: 'Conteúdo da nota');

    expect(find.text(AppStrings.editDay), findsOneWidget);
    expect(find.text(AppStrings.newNote), findsNothing);
    expect(find.text(AppStrings.newActivity), findsNothing);
    expect(find.textContaining('Conteúdo da nota'), findsNothing);

    await tester.tap(find.text(AppStrings.editDay));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.newNote), findsOneWidget);
    expect(find.text(AppStrings.newActivity), findsOneWidget);

    await tester.tap(find.text(AppStrings.finishDayEditing));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.newNote), findsNothing);
    expect(find.text(AppStrings.newActivity), findsNothing);
  });

  testWidgets('o conteúdo da nota aparece ao clicar no cartão', (tester) async {
    await pumpPanel(tester, note: 'Conteúdo da nota');

    expect(find.text(AppStrings.noteIndex(1)), findsOneWidget);
    expect(find.textContaining('Conteúdo da nota'), findsNothing);

    await tester.tap(find.text(AppStrings.noteIndex(1)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Conteúdo da nota'), findsWidgets);
  });

  testWidgets('cria uma segunda nota com o nível escolhido', (tester) async {
    final (controller, toat) = await pumpPanel(tester, note: 'Primeira');

    await tester.tap(find.text(AppStrings.editDay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.newNote));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Segunda nota');
    await tester.tap(
      find.descendant(
        of: find.byType(AppDialogSurface),
        matching: find.text(AppStrings.sensitivitySecret),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.saveNote));
    await tester.pumpAndSettle();

    expect(controller.day?.notes.length, 2);
    expect(controller.day?.notes.last.content, 'Segunda nota');
    expect(controller.day?.notes.last.sensitivity, SensitivityLevel.sigiloso);
    expect(find.text(AppStrings.noteIndex(2)), findsOneWidget);

    for (final message in [...toat.messages]) {
      toat.dismiss(message.id);
    }
    await tester.pumpAndSettle();
  });
}
