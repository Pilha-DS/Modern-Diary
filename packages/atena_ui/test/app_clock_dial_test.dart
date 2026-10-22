import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

/// Centro da posição de um valor na órbita, para o toque.
Offset _positionOf(WidgetTester tester, int count, int value) {
  final rect = tester.getRect(find.byType(AppClockDial));
  final radius = rect.width / 2 - 20;
  final angle = -math.pi / 2 + 2 * math.pi * value / count;
  return rect.center +
      Offset(radius * 0.9 * math.cos(angle), radius * 0.9 * math.sin(angle));
}

void main() {
  testWidgets('escolhe a hora tocando na órbita de 24 posições', (
    tester,
  ) async {
    var hour = 0;

    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => AppClockDial(
            count: 24,
            value: hour,
            semanticLabel: 'Hora',
            onChanged: (value) => setState(() => hour = value),
          ),
        ),
      ),
    );

    // 21 h fica a 315° do topo: canto superior esquerdo.
    await tester.tapAt(_positionOf(tester, 24, 21));
    await tester.pumpAndSettle();

    expect(hour, 21);
  });

  testWidgets('escolhe o minuto tocando na órbita de 60 posições', (
    tester,
  ) async {
    var minute = 0;

    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => AppClockDial(
            count: 60,
            labelEvery: 5,
            value: minute,
            semanticLabel: 'Minuto',
            onChanged: (value) => setState(() => minute = value),
          ),
        ),
      ),
    );

    // 45 min fica a 270° do topo: lado esquerdo.
    await tester.tapAt(_positionOf(tester, 60, 45));
    await tester.pumpAndSettle();

    expect(minute, 45);
  });

  testWidgets('o relógio devolve hora e minuto escolhidos', (tester) async {
    TimeOfDay? picked;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: AppButton(
                label: 'abrir',
                onPressed: () async {
                  picked = await showAppTimePicker(
                    context,
                    title: 'Escolher horário',
                    hoursLabel: 'Hora',
                    minutesLabel: 'Minuto',
                    cancelLabel: 'Cancelar',
                    confirmLabel: 'Confirmar',
                    closeLabel: 'Fechar',
                    initial: const TimeOfDay(hour: 8, minute: 10),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Hora'), findsOneWidget);
    expect(find.text('Minuto'), findsOneWidget);
    expect(find.byType(AppClockDial), findsNWidgets(2));

    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(picked, const TimeOfDay(hour: 8, minute: 10));
    expect(find.byType(AppClockDial), findsNothing);
  });

  testWidgets('fechar o relógio devolve null', (tester) async {
    TimeOfDay? picked = const TimeOfDay(hour: 1, minute: 1);
    var wasCancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: AppButton(
                label: 'abrir',
                onPressed: () async {
                  picked = await showAppTimePicker(
                    context,
                    title: 'Escolher horário',
                    hoursLabel: 'Hora',
                    minutesLabel: 'Minuto',
                    cancelLabel: 'Cancelar',
                    confirmLabel: 'Confirmar',
                    closeLabel: 'Fechar',
                  );
                  wasCancelled = picked == null;
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(wasCancelled, isTrue);
  });

  testWidgets('o campo mostra o horário e limpa pelo botão', (tester) async {
    String? value = '09:30';
    var opened = false;

    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => AppTimeField(
            label: 'Horário (opcional)',
            placeholder: 'Escolher horário',
            value: value,
            onPressed: () => opened = true,
            clearLabel: 'Remover horário',
            onClear: () => setState(() => value = null),
          ),
        ),
      ),
    );

    expect(find.text('09:30'), findsOneWidget);

    await tester.tap(find.text('09:30'));
    expect(opened, isTrue);

    await tester.tap(find.byTooltip('Remover horário'));
    await tester.pumpAndSettle();

    expect(find.text('09:30'), findsNothing);
    expect(find.text('Escolher horário'), findsOneWidget);
  });
}
