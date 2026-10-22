import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

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
  testWidgets('cresce no hover e volta ao tamanho normal ao sair', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const AppHoverCard(
          child: SizedBox(key: ValueKey('cartao'), width: 120, height: 120),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await tester.pump();

    final center = tester.getCenter(find.byKey(const ValueKey('cartao')));
    await gesture.moveTo(center);
    await tester.pumpAndSettle();

    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      1.05,
    );

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
}
