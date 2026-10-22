import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

Future<void> pumpToat(WidgetTester tester, ToatController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: ToatHost(
        controller: controller,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ),
  );
}

void main() {
  testWidgets('TOAT agrupa mensagem repetida em sequência', (tester) async {
    final controller = ToatController();
    addTearDown(controller.dispose);
    await pumpToat(tester, controller);

    controller.show('Tudo certo.', variant: ToatVariant.warning);
    controller.show('Tudo certo.', variant: ToatVariant.warning);
    await tester.pump();

    expect(find.text('Tudo certo.'), findsOneWidget);
  });

  testWidgets('sucesso fecha sozinho depois de alguns segundos', (
    tester,
  ) async {
    final controller = ToatController();
    addTearDown(controller.dispose);
    await pumpToat(tester, controller);

    controller.show('Salvo.', variant: ToatVariant.success);
    await tester.pump();
    expect(find.text('Salvo.'), findsOneWidget);

    await tester.pump(
      ToatController.autoDismissDuration + const Duration(seconds: 1),
    );
    expect(find.text('Salvo.'), findsNothing);
  });

  testWidgets('aviso não fecha sozinho', (tester) async {
    final controller = ToatController();
    addTearDown(controller.dispose);
    await pumpToat(tester, controller);

    controller.show('Cuidado.', variant: ToatVariant.warning);
    await tester.pump();
    await tester.pump(
      ToatController.autoDismissDuration + const Duration(seconds: 5),
    );

    expect(find.text('Cuidado.'), findsOneWidget);
  });

  testWidgets('mostra no máximo três TOATs e remove o mais antigo', (
    tester,
  ) async {
    final controller = ToatController();
    addTearDown(controller.dispose);
    await pumpToat(tester, controller);

    controller.show('Primeira', variant: ToatVariant.warning);
    controller.show('Segunda', variant: ToatVariant.warning);
    controller.show('Terceira', variant: ToatVariant.warning);
    controller.show('Quarta', variant: ToatVariant.warning);
    await tester.pump();

    expect(find.text('Primeira'), findsNothing);
    expect(find.text('Segunda'), findsOneWidget);
    expect(find.text('Terceira'), findsOneWidget);
    expect(find.text('Quarta'), findsOneWidget);
  });
}
