import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('tocar na linha alterna o valor e o switch reflete o estado', (
    tester,
  ) async {
    var value = false;

    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => AppSwitchRow(
            label: 'Criar',
            icon: Icons.add_rounded,
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    expect(value, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    // Tocar no próprio controle também alterna, sem disparar duas vezes.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('expõe a linha com o rótulo para o leitor de tela', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(AppSwitchRow(label: 'Alterar', value: true, onChanged: (_) {})),
    );

    // Uma única entrada na árvore semântica: rótulo e estado vêm da linha,
    // não de um rótulo solto ao lado do controle.
    expect(find.bySemanticsLabel('Alterar'), findsOneWidget);
  });

  testWidgets('rótulo longo não estoura a linha', (tester) async {
    tester.view.physicalSize = const Size(200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 180,
          child: AppSwitchRow(
            label: 'Conhecimentos com um nome bem comprido',
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
