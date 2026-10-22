import 'package:atena_ui/atena_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromApi devolve o nível conhecido e cai no padrão', () {
    expect(SensitivityLevel.fromApi('sigiloso'), SensitivityLevel.sigiloso);
    expect(SensitivityLevel.fromApi('desconhecido'), SensitivityLevel.publico);
    expect(
      SensitivityLevel.fromApi(null, fallback: SensitivityLevel.basico),
      SensitivityLevel.basico,
    );
  });

  test('all não é nível de registro', () {
    expect(SensitivityLevel.dataLevels, isNot(contains(SensitivityLevel.all)));
    expect(SensitivityLevel.dataLevels.first, SensitivityLevel.publico);
  });

  testWidgets('seletor mostra os rótulos e devolve a escolha', (tester) async {
    SensitivityLevel? selected;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SensitivitySelector(
            label: 'Nível',
            selected: SensitivityLevel.publico,
            labelOf: (level) => level.name,
            onChanged: (level) => selected = level,
          ),
        ),
      ),
    );

    expect(find.text('publico'), findsOneWidget);
    expect(find.text('sigiloso'), findsOneWidget);
    expect(find.text('all'), findsNothing);

    await tester.tap(find.text('sigiloso'));
    expect(selected, SensitivityLevel.sigiloso);
  });
}
