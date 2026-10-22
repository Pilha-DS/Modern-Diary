import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      backgroundColor: AppColors.grayLight,
      body: SizedBox(width: 800, height: 600, child: child),
    ),
  );
}

class _TapRecorder {
  String? last;
}

/// Localiza a posição de cada nó tocando uma grade de pontos.
///
/// Os testes não têm acesso às posições internas da simulação; o toque chama
/// `onNodeTap`, então a grade revela onde cada nó parou.
Future<Map<String, Offset>> _findNodes(
  WidgetTester tester,
  Set<String> ids,
  _TapRecorder recorder,
) async {
  final found = <String, Offset>{};
  final rect = tester.getRect(find.byType(NetworkGraph));
  for (var y = rect.top + 4;
      y < rect.bottom - 4 && found.length < ids.length;
      y += 24) {
    for (var x = rect.left + 4;
        x < rect.right - 4 && found.length < ids.length;
        x += 24) {
      recorder.last = null;
      await tester.tapAt(Offset(x, y));
      await tester.pump();
      final id = recorder.last;
      if (id != null && ids.contains(id)) {
        found.putIfAbsent(id, () => Offset(x, y));
      }
    }
  }
  return found;
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

  testWidgets('arrastar um nó muda a posição e fixa o nó', (tester) async {
    await tester.pumpWidget(
      _host(
        NetworkGraph(
          nodes: const [
            NetworkNode(id: '1', label: 'Criptografia', tooltip: 'Nó movido'),
          ],
          edges: const [],
          onNodeTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final graph = find.byType(NetworkGraph);
    final center = tester.getCenter(graph);
    final target = center + const Offset(160, 80);
    await tester.dragFrom(center, target - center);
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(target);
    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();

    // A prévia aparece no ponto para onde o nó foi arrastado.
    expect(find.text('Nó movido'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('modo de conexão conecta um nó ao outro pelo arrasto', (
    tester,
  ) async {
    final recorder = _TapRecorder();
    final connections = <(String, String)>[];
    final controller = NetworkGraphController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        NetworkGraph(
          controller: controller,
          nodes: const [
            NetworkNode(id: '1', label: 'Um', weight: 8),
            NetworkNode(id: '2', label: 'Dois', weight: 8),
          ],
          edges: const [],
          onNodeTap: (node) => recorder.last = node.id,
          onConnect: (source, target) =>
              connections.add((source.id, target.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byType(NetworkGraph));
    final located = await _findNodes(tester, {'1', '2'}, recorder);
    expect(located.keys.toSet(), {'1', '2'});

    // Fixa cada nó em um ponto conhecido, longe do outro.
    final firstSpot = Offset(rect.left + 140, rect.top + 120);
    final secondSpot = Offset(rect.right - 140, rect.bottom - 120);
    final firstStart = located['1']!;
    await tester.dragFrom(firstStart, firstSpot - firstStart);
    await tester.pumpAndSettle();

    // O outro nó se moveu com a simulação; localiza de novo antes de mover.
    final again = await _findNodes(tester, {'2'}, recorder);
    final secondStart = again['2']!;
    await tester.dragFrom(secondStart, secondSpot - secondStart);
    await tester.pumpAndSettle();

    controller.setConnectMode(true);
    await tester.pump();

    await tester.dragFrom(firstSpot, secondSpot - firstSpot);
    await tester.pumpAndSettle();

    expect(connections, [('1', '2')]);

    // Fora do modo de conexão, o mesmo arrasto move o nó e não conecta.
    controller.setConnectMode(false);
    await tester.pump();
    await tester.dragFrom(firstSpot, const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(connections, [('1', '2')]);
  });

  testWidgets('controller reorganiza, centraliza e dá zoom sem quebrar', (
    tester,
  ) async {
    final controller = NetworkGraphController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        NetworkGraph(
          controller: controller,
          nodes: const [
            NetworkNode(id: '1', label: 'Um', weight: 3),
            NetworkNode(id: '2', label: 'Dois'),
          ],
          edges: const [NetworkEdge(source: '1', target: '2')],
          onNodeTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.updateSettings(
      controller.settings.copyWith(repulsion: 2, gravity: 0.5),
    );
    controller.zoomIn();
    controller.zoomOut();
    controller.resetView();
    controller.reorganize();
    await tester.pumpAndSettle();

    expect(find.byType(NetworkGraph), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('o layout fica lembrado no controller para reabrir igual', (
    tester,
  ) async {
    final controller = NetworkGraphController();
    addTearDown(controller.dispose);

    Widget graph() => _host(
      NetworkGraph(
        controller: controller,
        nodes: const [
          NetworkNode(id: '1', label: 'Um'),
          NetworkNode(id: '2', label: 'Dois'),
        ],
        edges: const [NetworkEdge(source: '1', target: '2')],
        onNodeTap: (_) {},
      ),
    );

    await tester.pumpWidget(graph());
    await tester.pumpAndSettle();

    for (final id in ['1', '2']) {
      expect(controller.rememberedPositionOf(id), isNotNull);
    }
    final before = controller.rememberedPositionOf('1')!;

    // Reabrir o grafo (tela cheia, troca de aba) continua de onde parou.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(graph());
    await tester.pumpAndSettle();

    expect(controller.rememberedPositionOf('1'), isNotNull);
    expect(
      (controller.rememberedPositionOf('1')! - before).distance,
      lessThan(0.1),
    );
    expect(tester.takeException(), isNull);
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
