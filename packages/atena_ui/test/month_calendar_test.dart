import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

const _weekdays = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      backgroundColor: AppColors.grayLight,
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );
}

void main() {
  testWidgets('mostra todos os dias do mês e marca o dia selecionado', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          marks: const {
            5: CalendarDayMark(hasNote: true),
            6: CalendarDayMark(activitiesTotal: 2, activitiesDone: 1),
            7: CalendarDayMark(
              activitiesTotal: 1,
              priority: CalendarPriority.high,
            ),
          },
          selectedDay: DateTime(2026, 10, 19),
          today: DateTime(2026, 10, 19),
          daySemanticLabel: (day, mark) =>
              '${day.day} de outubro, ${mark.activitiesTotal} atividades',
          onDaySelected: (_) {},
        ),
      ),
    );

    expect(find.text('Outubro'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('10'), findsNWidgets(2));
  });

  testWidgets('toque no dia devolve o número do dia', (tester) async {
    int? selected;

    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          onDaySelected: (day) => selected = day,
        ),
      ),
    );

    await tester.tap(find.text('20'));
    await tester.pump();

    expect(selected, 20);
  });

  testWidgets('modo compacto abre o mês pelo cartão', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          compact: true,
          onTap: () => tapped = true,
          cardSemanticLabel: 'Outubro de 2026',
        ),
      ),
    );

    await tester.tap(find.text('Outubro'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('sem marcação mostra apenas os números', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 2,
          monthName: 'Fevereiro',
          weekdayLabels: _weekdays,
        ),
      ),
    );

    expect(find.text('28'), findsOneWidget);
    expect(find.text('29'), findsNothing);
  });

  testWidgets('modo compacto mantém a mesma altura em meses de 4 a 6 semanas', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: Row(
            children: [
              for (final month in [2, 3, 8])
                Expanded(
                  child: MonthCalendar(
                    compact: true,
                    year: 2026,
                    month: month,
                    monthName: 'Mês $month',
                    weekdayLabels: _weekdays,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final heights = [
      for (final month in [2, 3, 8])
        tester
            .getSize(
              find.byWidgetPredicate(
                (widget) => widget is MonthCalendar && widget.month == month,
              ),
            )
            .height,
    ];

    expect(heights.toSet().length, 1);
  });

  testWidgets('o dia atual fica verde e o hover pinta os dias de cinza-claro', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          today: DateTime(2026, 10, 19),
          onDaySelected: (_) {},
        ),
      ),
    );

    Color? colorOf(String day) {
      final container = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text(day),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    final colors = Theme.of(tester.element(find.byType(MonthCalendar)))
        .colorScheme;

    expect(
      colorOf('19'),
      AppSemanticColors.of(tester.element(find.byType(MonthCalendar)))
          .brandSoft,
    );
    expect(colorOf('12'), Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.text('12')));
    await tester.pumpAndSettle();

    expect(colorOf('12'), colors.secondaryContainer);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();

    expect(colorOf('12'), Colors.transparent);
  });

  testWidgets('dia com conteúdo abre a prévia ao lado após o hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          marks: const {
            12: CalendarDayMark(hasNote: true),
            13: CalendarDayMark(activitiesTotal: 2, activitiesDone: 1),
          },
          onDaySelected: (_) {},
          dayPreview: (context, day, mark) =>
              Text('prévia de ${day.day}', textDirection: TextDirection.ltr),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    // Dia com nota abre a prévia montada pelo chamador.
    await mouse.moveTo(tester.getCenter(find.text('12')));
    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();
    expect(find.text('prévia de 12'), findsOneWidget);

    // Mudar de dia troca a prévia.
    await mouse.moveTo(tester.getCenter(find.text('13')));
    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();
    expect(find.text('prévia de 12'), findsNothing);
    expect(find.text('prévia de 13'), findsOneWidget);

    // Dia sem conteúdo não abre prévia.
    await mouse.moveTo(tester.getCenter(find.text('20')));
    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();
    expect(find.textContaining('prévia de'), findsNothing);
  });

  testWidgets('a prévia fica do tamanho dela, encostada no dia', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          marks: const {12: CalendarDayMark(hasNote: true)},
          onDaySelected: (_) {},
          dayPreview: (context, day, mark) =>
              Container(key: const Key('previa-do-dia'), height: 40),
        ),
      ),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.text('12')));
    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();

    // O overlay entrega a tela inteira ao filho; a prévia não pode esticar.
    final preview = tester.getRect(find.byKey(const Key('previa-do-dia')));
    expect(preview.width, AppSpacing.hoverPreviewWidth);
    expect(preview.height, 40);

    final cell = tester.getRect(
      find.ancestor(
        of: find.text('12'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(preview.left, greaterThanOrEqualTo(cell.right));
    expect(preview.right, lessThanOrEqualTo(800));
  });

  testWidgets('seleção, nota, atividade e prioridade usam cores diferentes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          marks: const {
            12: CalendarDayMark(hasNote: true),
            13: CalendarDayMark(activitiesTotal: 1),
            14: CalendarDayMark(
              activitiesTotal: 1,
              priority: CalendarPriority.high,
            ),
          },
          selectedDay: DateTime(2026, 10, 11),
          onDaySelected: (_) {},
        ),
      ),
    );

    Color? colorOf(String day) {
      final container = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text(day),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    final context = tester.element(find.byType(MonthCalendar));
    final colors = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    expect(colorOf('11'), colors.primary);
    expect(colorOf('12'), colors.primaryContainer);
    expect(colorOf('13'), semanticColors.brandSoft);
    expect(colorOf('14'), semanticColors.warningSoft);
  });

  testWidgets('feriado usa o laranja e vem antes da prioridade alta', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          marks: const {
            12: CalendarDayMark(holiday: 'Finados'),
            13: CalendarDayMark(
              holiday: 'Finados',
              activitiesTotal: 1,
              priority: CalendarPriority.high,
            ),
          },
          onDaySelected: (_) {},
        ),
      ),
    );

    Color? colorOf(String day) {
      final container = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text(day),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (container.decoration as BoxDecoration?)?.color;
    }

    final semanticColors = AppSemanticColors.of(
      tester.element(find.byType(MonthCalendar)),
    );

    expect(colorOf('12'), semanticColors.holidaySoft);
    expect(colorOf('13'), semanticColors.holidaySoft);
    expect(
      semanticColors.holiday,
      isNot(semanticColors.warning),
      reason: 'feriado não pode se confundir com o amarelo de prioridade alta',
    );
  });

  testWidgets('hoje selecionado continua verde, com anel de seleção', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MonthCalendar(
          year: 2026,
          month: 10,
          monthName: 'Outubro',
          weekdayLabels: _weekdays,
          today: DateTime(2026, 10, 19),
          selectedDay: DateTime(2026, 10, 19),
          onDaySelected: (_) {},
        ),
      ),
    );

    final container = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text('19'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(
      decoration.color,
      AppSemanticColors.of(tester.element(find.byType(MonthCalendar)))
          .brandSoft,
    );
    expect(decoration.border, isNotNull);
  });
}
