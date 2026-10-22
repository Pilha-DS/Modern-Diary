import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/features/life/domain/life_models.dart';
import 'package:modern_diary/src/features/life/presentation/life_graph_controller.dart';

import 'support/fake_life_data_source.dart';

void main() {
  test('carrega o grafo com os nós e as conexões', () async {
    final source = FakeLifeDataSource(
      nodes: [
        lifeNode(
          id: 'knowledge:1',
          type: LifeEntityType.knowledge,
          title: 'SQL',
        ),
        lifeNode(id: 'goal:2', type: LifeEntityType.goal, title: 'Backend'),
      ],
      edges: const [
        LifeGraphEdge(source: 'goal:2', target: 'knowledge:1', kind: 'custom'),
      ],
    );
    final controller = LifeGraphController(source);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.isLoading, isFalse);
    expect(controller.error, isNull);
    expect(controller.graph.nodes, hasLength(2));
    expect(controller.graph.connectionsOf('knowledge:1').single.node.ref, '2');
  });

  test('o filtro acumula tipos e volta para todos', () async {
    final source = FakeLifeDataSource();
    final controller = LifeGraphController(source);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.toggleType(LifeEntityType.goal);
    await controller.toggleType(LifeEntityType.note);
    expect(source.typeRequests.last, [
      LifeEntityType.goal,
      LifeEntityType.note,
    ]);

    await controller.toggleType(LifeEntityType.goal);
    expect(source.typeRequests.last, [LifeEntityType.note]);

    await controller.clearTypes();
    expect(source.typeRequests.last, isEmpty);
    expect(controller.types, isEmpty);
  });

  test('conectar envia o par e recarrega o grafo', () async {
    final source = FakeLifeDataSource(
      nodes: [
        lifeNode(id: 'note:1', type: LifeEntityType.note, title: 'Ideia'),
        lifeNode(id: 'goal:2', type: LifeEntityType.goal, title: 'Meta'),
      ],
    );
    final controller = LifeGraphController(source);
    addTearDown(controller.dispose);
    await controller.load();

    final error = await controller.connect(
      controller.graph.nodeById('note:1')!,
      controller.graph.nodeById('goal:2')!,
    );

    expect(error, isNull);
    expect(source.linkCalls, 1);
    expect(source.lastSource?.id, 'note:1');
    expect(source.lastTarget?.id, 'goal:2');
    expect(controller.isBusy, isFalse);
  });

  test('falha ao conectar devolve o erro sem quebrar o grafo', () async {
    final source = FakeLifeDataSource(
      nodes: [
        lifeNode(id: 'note:1', type: LifeEntityType.note),
        lifeNode(id: 'goal:2', type: LifeEntityType.goal),
      ],
      edges: const [
        LifeGraphEdge(source: 'goal:2', target: 'note:1', kind: 'custom'),
      ],
    );
    source.linkError = const ApiException(
      code: 'LIFE_LINK_EXISTS',
      message: 'Estes registros já estão conectados.',
      statusCode: 409,
    );
    final controller = LifeGraphController(source);
    addTearDown(controller.dispose);
    await controller.load();

    final error = await controller.connect(
      controller.graph.nodeById('note:1')!,
      controller.graph.nodeById('goal:2')!,
    );

    expect(error?.code, 'LIFE_LINK_EXISTS');
    expect(controller.graph.nodes, hasLength(2));
    expect(controller.isBusy, isFalse);
  });

  test('desfazer a conexão remove a aresta e recarrega', () async {
    final source = FakeLifeDataSource(
      nodes: [
        lifeNode(id: 'note:1', type: LifeEntityType.note),
        lifeNode(id: 'goal:2', type: LifeEntityType.goal),
      ],
      edges: const [
        LifeGraphEdge(
          source: 'goal:2',
          target: 'note:1',
          kind: 'custom',
          linkId: 7,
        ),
      ],
    );
    final controller = LifeGraphController(source);
    addTearDown(controller.dispose);
    await controller.load();

    final error = await controller.disconnect(
      controller.graph.nodeById('note:1')!,
      controller.graph.nodeById('goal:2')!,
    );

    expect(error, isNull);
    expect(source.unlinkCalls, 1);
    expect(controller.graph.edges, isEmpty);
  });

  test('erro de carregamento zera o grafo e fica disponível', () async {
    final source = FakeLifeDataSource()
      ..error = const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Sem conexão.',
      );
    final controller = LifeGraphController(source);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.error?.code, 'NETWORK_ERROR');
    expect(controller.graph.nodes, isEmpty);
    expect(controller.isLoading, isFalse);
  });
}
