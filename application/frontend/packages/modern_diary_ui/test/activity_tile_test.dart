import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('mostra horário e nível já traduzidos', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ActivityTile(
          title: 'Estudar FastAPI',
          timeLabel: '09:30',
          sensitivityLabel: 'Complexo',
          priority: ActivityPriority.high,
          priorityLabel: 'Alta',
          isDone: false,
        ),
      ),
    );

    expect(find.text('Estudar FastAPI'), findsOneWidget);
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('Complexo'), findsOneWidget);
    expect(find.text('Alta'), findsOneWidget);
  });

  testWidgets('sem nível informado a linha não mostra etiqueta de nível', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ActivityTile(
          title: 'Revisar meta',
          priority: ActivityPriority.low,
          priorityLabel: 'Baixa',
          isDone: true,
        ),
      ),
    );

    expect(find.byIcon(Icons.shield_outlined), findsNothing);
    expect(find.text('Baixa'), findsOneWidget);
  });
}
