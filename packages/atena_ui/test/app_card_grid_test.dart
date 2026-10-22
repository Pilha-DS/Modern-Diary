import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      backgroundColor: AppColors.grayLight,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    ),
  );
}

Widget _card(String title, {required int lines, bool footer = false}) {
  return AppSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title),
        for (var line = 0; line < lines; line++) Text('linha $line'),
        const Spacer(),
        if (footer) const Text('rodapé'),
      ],
    ),
  );
}

void main() {
  testWidgets('cartões da mesma linha ficam com a mesma altura', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        AppCardGrid(
          minCardWidth: 200,
          children: [
            _card('Curto', lines: 1),
            _card('Longo', lines: 6, footer: true),
            _card('Médio', lines: 3),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byType(AppSurface);
    expect(cards, findsNWidgets(3));

    final first = tester.getSize(cards.at(0));
    final second = tester.getSize(cards.at(1));
    final third = tester.getSize(cards.at(2));

    expect(first.height, second.height);
    expect(third.height, second.height);
    expect(first.width, second.width);
  });

  testWidgets('o rodapé fica no fim do cartão esticado', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        AppCardGrid(
          minCardWidth: 200,
          children: [
            _card('Curto', lines: 1, footer: true),
            _card('Longo', lines: 8, footer: true),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byType(AppSurface);
    final shortBottom = tester.getBottomLeft(cards.at(0)).dy;
    final longBottom = tester.getBottomLeft(cards.at(1)).dy;
    expect(shortBottom, closeTo(longBottom, 0.5));

    final shortFooter = tester.getBottomLeft(find.text('rodapé').first).dy;
    expect(shortFooter, greaterThan(shortBottom - 100));
  });

  testWidgets('em largura estreita cada cartão ocupa a linha inteira', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        AppCardGrid(
          minCardWidth: 200,
          children: [_card('Um', lines: 1), _card('Dois', lines: 2)],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byType(AppSurface);
    expect(
      tester.getTopLeft(cards.at(1)).dy,
      greaterThan(tester.getTopLeft(cards.at(0)).dy),
    );
    expect(tester.getSize(cards.first).width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });
}
