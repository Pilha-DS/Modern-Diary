import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('mostra as iniciais quando não há foto', (tester) async {
    await tester.pumpWidget(
      _app(
        const AppHeader(
          title: 'Modern Diary',
          subtitle: 'jonathan',
          avatarLabel: 'jonathan',
        ),
      ),
    );

    expect(find.text('Modern Diary'), findsOneWidget);
    expect(find.text('jonathan'), findsOneWidget);
    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('o avatar abre o menu escondido e executa a ação', (
    tester,
  ) async {
    var opened = false;

    await tester.pumpWidget(
      _app(
        AppHeader(
          title: 'Modern Diary',
          avatarLabel: 'jonathan cardoso',
          avatarTooltip: 'Perfil e configurações',
          menuItems: [
            AppHeaderMenuItem(
              icon: Icons.settings_outlined,
              label: 'Configurações básicas',
              onSelected: () => opened = true,
            ),
          ],
        ),
      ),
    );

    expect(find.text('JC'), findsOneWidget);
    expect(find.text('Configurações básicas'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Perfil e configurações'));
    await tester.pumpAndSettle();

    expect(find.text('Configurações básicas'), findsOneWidget);

    await tester.tap(find.text('Configurações básicas'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });

  testWidgets('o logo leva para o início quando tem ação', (tester) async {
    var pressed = 0;

    await tester.pumpWidget(
      _app(
        AppHeader(
          title: 'Modern Diary',
          avatarLabel: 'jonathan',
          logoTooltip: 'Ir para Início',
          onLogoPressed: () => pressed++,
        ),
      ),
    );

    expect(find.bySemanticsLabel('Ir para Início'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Ir para Início'));
    await tester.pumpAndSettle();

    expect(pressed, 1);
  });

  testWidgets('foto de perfil ocupa o avatar no lugar das iniciais', (
    tester,
  ) async {
    // PNG 1x1 transparente, só para o avatar ter imagem válida.
    final image = MemoryImage(
      Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8'
          'z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
        ),
      ),
    );

    await tester.pumpWidget(
      _app(
        AppHeader(
          title: 'Modern Diary',
          avatarLabel: 'jonathan',
          avatarImage: image,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('J'), findsNothing);
  });
}
