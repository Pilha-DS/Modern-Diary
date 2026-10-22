import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/knowledge/domain/knowledge_models.dart';
import 'package:modern_diary/src/features/knowledge/presentation/knowledge_graph_view.dart';
import 'package:atena_ui/atena_ui.dart';

KnowledgeGraphData _graph({int weight = 1, bool withEdge = false}) {
  return KnowledgeGraphData(
    nodes: [
      KnowledgeNodeData(id: 1, title: 'Um', degree: weight),
      KnowledgeNodeData(id: 2, title: 'Dois', degree: weight),
    ],
    edges: withEdge ? const [KnowledgeEdge(source: 1, target: 2)] : const [],
    total: 2,
    truncated: false,
  );
}

Future<void> _pumpGraph(
  WidgetTester tester,
  KnowledgeGraphData graph, {
  ValueChanged<KnowledgeNodeData>? onNodeTap,
  void Function(KnowledgeNodeData source, KnowledgeNodeData target)? onConnect,
  Size size = const Size(900, 700),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        backgroundColor: AppColors.grayLight,
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: KnowledgeGraphView(
              graph: graph,
              onNodeTap: onNodeTap ?? (_) {},
              onConnect: onConnect,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Localiza cada nó tocando uma grade dentro do desenho.
Future<Map<int, Offset>> _findNodes(
  WidgetTester tester,
  Set<int> ids,
  List<int> taps,
) async {
  final found = <int, Offset>{};
  final rect = tester.getRect(find.byType(NetworkGraph));
  for (
    var y = rect.top + 4;
    y < rect.bottom - 4 && found.length < ids.length;
    y += 24
  ) {
    for (
      var x = rect.left + 4;
      x < rect.right - 4 && found.length < ids.length;
      x += 24
    ) {
      taps.clear();
      await tester.tapAt(Offset(x, y));
      await tester.pump();
      if (taps.isNotEmpty && ids.contains(taps.last)) {
        found.putIfAbsent(taps.last, () => Offset(x, y));
      }
    }
  }
  return found;
}

void main() {
  testWidgets('o grafo tem controles de posição, força e conexão', (
    tester,
  ) async {
    await _pumpGraph(tester, _graph(withEdge: true));

    expect(find.text(AppStrings.knowledgeGraphConnect), findsOneWidget);
    expect(find.text(AppStrings.knowledgeGraphSettings), findsOneWidget);

    await tester.tap(find.text(AppStrings.knowledgeGraphSettings));
    await tester.pumpAndSettle();

    expect(find.byType(AppSliderRow), findsNWidgets(3));
    expect(find.text(AppStrings.knowledgeGraphRepulsion), findsOneWidget);
    expect(find.text(AppStrings.knowledgeGraphLinkDistance), findsOneWidget);
    expect(find.text(AppStrings.knowledgeGraphGravity), findsOneWidget);

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip(AppStrings.knowledgeGraphReorganize));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.knowledgeGraphCenter));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.knowledgeGraphZoomIn));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.knowledgeGraphZoomOut));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('o modo de conexão mostra a instrução e liga um nó ao outro', (
    tester,
  ) async {
    final taps = <int>[];
    final connections = <(int, int)>[];

    await _pumpGraph(
      tester,
      _graph(weight: 8),
      onNodeTap: (node) => taps.add(node.id),
      onConnect: (source, target) => connections.add((source.id, target.id)),
    );

    await tester.tap(find.text(AppStrings.knowledgeGraphConnect));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.knowledgeGraphConnectHint), findsOneWidget);

    final located = await _findNodes(tester, {1, 2}, taps);
    expect(located.keys.toSet(), {1, 2});

    final first = located[1]!;
    final second = located[2]!;
    await tester.dragFrom(first, second - first);
    await tester.pumpAndSettle();

    expect(connections, [(1, 2)]);

    await tester.tap(find.text(AppStrings.knowledgeGraphConnectOn));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.knowledgeGraphConnectHint), findsNothing);
  });

  testWidgets('o grafo abre em tela cheia e volta para a versão encaixada', (
    tester,
  ) async {
    await _pumpGraph(
      tester,
      _graph(withEdge: true),
      onConnect: (source, target) {},
    );

    await tester.tap(find.byTooltip(AppStrings.knowledgeGraphFullscreen));
    await tester.pumpAndSettle();

    expect(
      find.byTooltip(AppStrings.knowledgeGraphFullscreenExit),
      findsOneWidget,
    );
    expect(find.byType(NetworkGraph), findsOneWidget);
    expect(find.text(AppStrings.knowledgeGraphSettings), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.knowledgeGraphFullscreenExit));
    await tester.pumpAndSettle();

    expect(find.byTooltip(AppStrings.knowledgeGraphFullscreen), findsOneWidget);
    expect(find.byType(NetworkGraph), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('o grafo e os ajustes cabem em tela estreita', (tester) async {
    await _pumpGraph(
      tester,
      _graph(withEdge: true),
      size: const Size(420, 800),
      onConnect: (source, target) {},
    );

    await tester.tap(find.text(AppStrings.knowledgeGraphSettings));
    await tester.pumpAndSettle();
    expect(find.byType(AppSliderRow), findsNWidgets(3));

    await tester.tap(find.text(AppStrings.knowledgeGraphConnect));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.knowledgeGraphConnectHint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
