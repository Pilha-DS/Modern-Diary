import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

void main() {
  testWidgets('mostra rótulo, valor e devolve o ajuste', (tester) async {
    var value = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: StatefulBuilder(
            builder: (context, setState) => AppSliderRow(
              label: 'Repulsão',
              icon: Icons.open_in_full_rounded,
              value: value,
              min: 0.3,
              max: 2.4,
              valueLabel: '${value.toStringAsFixed(1)}×',
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Repulsão'), findsOneWidget);
    expect(find.text('1.0×'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(value, greaterThan(1.0));
    expect(find.text('${value.toStringAsFixed(1)}×'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
