import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      backgroundColor: AppColors.grayLight,
      body: SizedBox(width: 800, height: 600, child: child),
    ),
  );
}

void main() {
  testWidgets('desenha nós e arestas da rede', (tester) async {
    await tester.pumpWidget(
      _host(
        NetworkGraph(
          semanticLabel: 'Rede de teste',
          nodes: const [
            NetworkNode(id: '1', label: 'Um', weight: 2),
            NetworkNode(id: '2', label: 'Dois'),
            NetworkNode(id: '3', label: 'Três'),
          ],
          edges: const [
            NetworkEdge(source: '1', target: '2'),
            NetworkEdge(source: '2', target: '3'),
          ],
          onNodeTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NetworkGraph), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sem nós não quebra e não dispara toque', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _host(
        NetworkGraph(
          nodes: const [],
          edges: const [],
          onNodeTap: (_) => tapped = true,
        ),
      ),
    );
    await tester.tap(find.byType(NetworkGraph));
    await tester.pumpAndSettle();

    expect(tapped, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hover no nó mostra o resumo só depois do tempo de espera', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        NetworkGraph(
          nodes: const [
            NetworkNode(
              id: '1',
              label: 'Criptografia',
              tooltip: '1 conexão · Moderado',
            ),
          ],
          edges: const [],
          onNodeTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Moderado'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    // Com um nó só, a simulação o deixa no centro da área.
    await mouse.moveTo(tester.getCenter(find.byType(NetworkGraph)));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('Moderado'), findsNothing);

    await tester.pump(AppDurations.hoverTooltip);
    await tester.pump();
    expect(find.text('Criptografia'), findsWidgets);
    expect(find.text('1 conexão · Moderado'), findsOneWidget);

    // Sair do nó fecha o resumo.
    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('1 conexão · Moderado'), findsNothing);
  });

  testWidgets('a prévia do nó abre ao lado dele, do tamanho do painel', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        NetworkGraph(
          nodes: const [NetworkNode(id: '1', label: 'Criptografia')],
          edges: const [],
          onNodeTap: (_) {},
          nodePreview: (context, node) =>
              Container(key: const Key('previa-do-no'), height: 80),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('previa-do-no')), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(NetworkGraph)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('previa-do-no')), findsNothing);

    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();

    // Com um nó só, ele fica no centro da área (400, 300).
    final preview = tester.getRect(find.byKey(const Key('previa-do-no')));
    expect(preview.width, closeTo(AppSpacing.hoverPreviewWidth, 0.01));
    expect(preview.height, 80);
    expect(preview.left, greaterThan(400));
    expect(preview.right, lessThanOrEqualTo(800));
    expect(preview.center.dy, closeTo(300, 1));

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('previa-do-no')), findsNothing);
  });

  testWidgets('a prévia não sai da área quando o nó fica na borda', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        NetworkGraph(
          nodes: const [
            NetworkNode(id: '1', label: 'Um'),
            NetworkNode(id: '2', label: 'Dois'),
            NetworkNode(id: '3', label: 'Três'),
          ],
          edges: const [],
          onNodeTap: (_) {},
          nodePreview: (context, node) =>
              Container(key: const Key('previa-do-no'), height: 240),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final graphCenter = tester.getCenter(find.byType(NetworkGraph));
    for (final offset in const [
      Offset(-340, -240),
      Offset(340, 240),
      Offset(-340, 240),
    ]) {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(graphCenter + offset);
      await tester.pump(AppDurations.hoverTooltip);
      await tester.pumpAndSettle();
      final preview = find.byKey(const Key('previa-do-no'));
      if (preview.evaluate().isNotEmpty) {
        final rect = tester.getRect(preview);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(600));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(800));
      }
      await mouse.removePointer();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('o chip dispara toque e remoção com rótulo', (tester) async {
    var opened = false;
    var removed = false;

    await tester.pumpWidget(
      _host(
        Center(
          child: AppChip(
            label: 'FastAPI',
            icon: Icons.link_rounded,
            onTap: () => opened = true,
            onDeleted: () => removed = true,
            deleteLabel: 'Remover FastAPI',
          ),
        ),
      ),
    );

    await tester.tap(find.text('FastAPI'));
    expect(opened, isTrue);

    await tester.tap(find.byTooltip('Remover FastAPI'));
    expect(removed, isTrue);
  });
}
