import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

void main() {
  testWidgets('mostra a contagem e limita o valor entre 0 e 1', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            width: 200,
            child: Column(
              children: [
                AppProgressBar(value: 0.5, label: '2/4'),
                AppProgressBar(value: 3, label: '9/9'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('2/4'), findsOneWidget);
    expect(find.text('9/9'), findsOneWidget);

    final bars = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bars.first.value, 0.5);
    expect(bars.last.value, 1);
  });
}
