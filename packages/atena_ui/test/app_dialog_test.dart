import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

void main() {
  testWidgets('modal mostra título, conteúdo e fecha pelo botão', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppDialog(
                context,
                title: 'Dia selecionado',
                closeLabel: 'Fechar',
                child: const Text('Conteúdo do dia'),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Dia selecionado'), findsOneWidget);
    expect(find.text('Conteúdo do dia'), findsOneWidget);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(find.text('Conteúdo do dia'), findsNothing);
  });
}
