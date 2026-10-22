import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

void main() {
  testWidgets('mostra as opções e devolve a escolha tocada', (tester) async {
    String selected = 'baixa';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AppChoiceChips<String>(
              label: 'Prioridade',
              options: const [
                AppChoiceOption(value: 'baixa', label: 'Baixa'),
                AppChoiceOption(value: 'alta', label: 'Alta'),
              ],
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Prioridade'), findsOneWidget);

    await tester.tap(find.text('Alta'));
    await tester.pump();

    expect(selected, 'alta');
  });
}
