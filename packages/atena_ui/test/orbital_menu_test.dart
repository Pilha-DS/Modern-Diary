import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

Widget _app(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Align(alignment: Alignment.bottomCenter, child: child),
    ),
  );
}

void main() {
  testWidgets('abre os itens orbitais ao tocar na bola e executa a ação', (
    tester,
  ) async {
    var selected = false;

    await tester.pumpWidget(
      _app(
        OrbitalMenu(
          semanticLabel: 'Menu de navegação',
          items: [
            OrbitalMenuItem(
              icon: Icons.home_outlined,
              label: 'Início',
              onSelected: () => selected = true,
            ),
            OrbitalMenuItem(
              icon: Icons.calendar_month_outlined,
              label: 'Calendário',
              onSelected: () {},
            ),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.home_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.hub_rounded));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    expect(selected, isTrue);
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });

  testWidgets('itens aparecem sem nome e o nome chega pelo tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        OrbitalMenu(
          semanticLabel: 'Menu de navegação',
          items: [
            OrbitalMenuItem(
              icon: Icons.flag_outlined,
              label: 'Metas',
              onSelected: () {},
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.hub_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Metas'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.flag_outlined)));
    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();

    expect(find.text('Metas'), findsOneWidget);
  });

  testWidgets('com seis itens cada alvo continua clicável', (tester) async {
    tester.view.physicalSize = const Size(1000, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const icons = [
      Icons.home_outlined,
      Icons.calendar_month_outlined,
      Icons.flag_outlined,
      Icons.hub_outlined,
      Icons.people_outline_rounded,
      Icons.logout_rounded,
    ];
    const labels = [
      'Início',
      'Calendário',
      'Metas',
      'Conhecimentos',
      'Usuários',
      'Sair',
    ];
    var knowledgeSelected = false;

    await tester.pumpWidget(
      _app(
        OrbitalMenu(
          semanticLabel: 'Menu de navegação',
          items: [
            for (var index = 0; index < labels.length; index++)
              OrbitalMenuItem(
                icon: icons[index],
                label: labels[index],
                onSelected: () {
                  if (labels[index] == 'Conhecimentos') {
                    knowledgeSelected = true;
                  }
                },
              ),
          ],
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.hub_rounded));
    await tester.pumpAndSettle();

    for (final icon in icons) {
      expect(find.byIcon(icon), findsOneWidget);
    }

    await tester.tap(find.byIcon(Icons.hub_outlined));
    await tester.pumpAndSettle();

    expect(knowledgeSelected, isTrue);
  });

  testWidgets(
    'item central fica no meio do arco, com os demais dos dois lados',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          OrbitalMenu(
            semanticLabel: 'Menu de navegação',
            items: [
              OrbitalMenuItem(
                icon: Icons.home_outlined,
                label: 'Início',
                isCentered: true,
                onSelected: () {},
              ),
              OrbitalMenuItem(
                icon: Icons.calendar_month_outlined,
                label: 'Calendário',
                onSelected: () {},
              ),
              OrbitalMenuItem(
                icon: Icons.flag_outlined,
                label: 'Metas',
                onSelected: () {},
              ),
              OrbitalMenuItem(
                icon: Icons.self_improvement_outlined,
                label: 'Conhecimentos',
                onSelected: () {},
              ),
              OrbitalMenuItem(
                icon: Icons.logout_rounded,
                label: 'Sair',
                onSelected: () {},
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.hub_rounded));
      await tester.pumpAndSettle();

      final ball = tester.getCenter(find.byIcon(Icons.close_rounded));
      final home = tester.getCenter(find.byIcon(Icons.home_outlined));
      final calendar = tester.getCenter(
        find.byIcon(Icons.calendar_month_outlined),
      );
      final leave = tester.getCenter(find.byIcon(Icons.logout_rounded));

      expect(home.dx, closeTo(ball.dx, 1));
      expect(home.dy, lessThan(ball.dy));
      expect(calendar.dx, lessThan(ball.dx));
      expect(leave.dx, greaterThan(ball.dx));
    },
  );

  testWidgets('itens usam a superfície invertida do tema', (tester) async {
    Future<Color?> circleColor(ThemeData theme, Color expected) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: OrbitalMenu(
                semanticLabel: 'Menu de navegação',
                items: [
                  OrbitalMenuItem(
                    icon: Icons.flag_outlined,
                    label: 'Metas',
                    onSelected: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.hub_rounded));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.flag_outlined),
              matching: find.byType(Container),
            )
            .first,
      );
      final color = (container.decoration as BoxDecoration).color;
      expect(color, expected);
      return color;
    }

    // Tema claro: o item fica escuro.
    expect(await circleColor(AppTheme.light(), AppColors.ink), AppColors.ink);
    // Tema escuro: o item fica claro.
    expect(
      await circleColor(AppTheme.dark(), AppColors.darkInk),
      AppColors.darkInk,
    );
  });
}
