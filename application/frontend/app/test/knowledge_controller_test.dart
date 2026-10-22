import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/features/knowledge/domain/knowledge_models.dart';
import 'package:modern_diary/src/features/knowledge/presentation/knowledge_controller.dart';

import 'support/fake_knowledge_data_source.dart';

KnowledgeItem _item(int id, {List<KnowledgeReference> relations = const []}) {
  return KnowledgeItem(
    id: id,
    title: 'Conhecimento $id',
    content: 'Conteúdo $id',
    links: const [],
    relations: relations,
    attachments: const [],
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  );
}

void main() {
  test('abre em lista e carrega as próximas páginas sob demanda', () async {
    final source = FakeKnowledgeDataSource(
      initial: [for (var id = 1; id <= 13; id++) _item(id)],
    );
    final controller = KnowledgeController(source);
    addTearDown(controller.dispose);

    expect(controller.view, KnowledgeView.list);

    await controller.loadFirstPage();

    expect(controller.items.length, 12);
    expect(controller.total, 13);
    expect(controller.hasMore, isTrue);

    await controller.loadMore();

    expect(controller.items.length, 13);
    expect(controller.hasMore, isFalse);
    expect(controller.isLoadingMore, isFalse);
  });

  test('troca para o grafo e carrega a rede uma vez', () async {
    final source = FakeKnowledgeDataSource(
      initial: [
        _item(1, relations: const [KnowledgeReference(id: 2, title: 'B')]),
        _item(2, relations: const [KnowledgeReference(id: 1, title: 'A')]),
      ],
    );
    final controller = KnowledgeController(source);
    addTearDown(controller.dispose);

    await controller.loadFirstPage();
    await controller.setView(KnowledgeView.graph);

    expect(controller.view, KnowledgeView.graph);
    expect(source.graphCalls, 1);
    expect(controller.graph?.nodes.length, 2);
    expect(controller.graph?.edges.length, 1);

    await controller.setView(KnowledgeView.list);
    await controller.setView(KnowledgeView.graph);

    expect(source.graphCalls, 1);
  });

  test('cria, atualiza e exclui conhecimento', () async {
    final source = FakeKnowledgeDataSource();
    final controller = KnowledgeController(source);
    addTearDown(controller.dispose);
    await controller.loadFirstPage();

    final createError = await controller.createItem(
      title: 'FastAPI',
      content: 'Framework',
      links: const [KnowledgeExternalLink(url: 'https://fastapi.tiangolo.com')],
      files: const [
        KnowledgeUploadFile(
          filename: 'nota.txt',
          bytes: [1, 2, 3],
          contentType: 'text/plain',
        ),
      ],
    );

    expect(createError, isNull);
    expect(controller.items.single.attachments.single.filename, 'nota.txt');

    final itemId = controller.items.single.id;
    final updateError = await controller.updateItem(itemId, title: 'FastAPI 2');

    expect(updateError, isNull);
    expect(controller.items.single.title, 'FastAPI 2');

    final deleteError = await controller.deleteItem(itemId);

    expect(deleteError, isNull);
    expect(controller.items, isEmpty);
  });

  test('conecta e desconecta dois conhecimentos', () async {
    final source = FakeKnowledgeDataSource(initial: [_item(1), _item(2)]);
    final controller = KnowledgeController(source);
    addTearDown(controller.dispose);
    await controller.loadFirstPage();

    await controller.addRelation(1, 2);

    expect(controller.items[0].relations.single.id, 2);
    expect(controller.items[1].relations.single.id, 1);

    await controller.removeRelation(1, 2);

    expect(controller.items[0].relations, isEmpty);
    expect(controller.items[1].relations, isEmpty);
  });

  test('mantém a rede na tela ao conectar e recarrega o grafo', () async {
    final source = FakeKnowledgeDataSource(initial: [_item(1), _item(2)]);
    final controller = KnowledgeController(source);
    addTearDown(controller.dispose);

    await controller.loadFirstPage();
    await controller.setView(KnowledgeView.graph);
    final previous = controller.graph;

    await controller.addRelation(1, 2);

    expect(controller.graph, isNotNull);
    expect(controller.graph, isNot(same(previous)));
    expect(controller.graph!.edges.length, 1);
    expect(source.graphCalls, 2);
  });

  test('adiciona e remove observações do conhecimento', () async {
    final source = FakeKnowledgeDataSource(initial: [_item(1)]);
    final controller = KnowledgeController(source);
    addTearDown(controller.dispose);
    await controller.loadFirstPage();

    final (observation, error) = await controller.addObservation(
      1,
      'Revisar decorators',
    );

    expect(error, isNull);
    expect(observation?.text, 'Revisar decorators');
    expect(controller.items.single.observations.single.id, observation!.id);

    final removeError = await controller.deleteObservation(1, observation.id);

    expect(removeError, isNull);
    expect(controller.items.single.observations, isEmpty);
  });

  test('expõe o endereço absoluto do anexo', () async {
    final source = FakeKnowledgeDataSource();
    final controller = KnowledgeController(source);
    addTearDown(controller.dispose);

    final uri = controller.attachmentDownloadUri(
      const KnowledgeAttachment(
        id: 1,
        filename: 'nota.txt',
        contentType: 'text/plain',
        sizeBytes: 3,
        downloadUrl: '/api/v1/knowledge/1/attachments/1/download?token=t',
      ),
    );

    expect(uri.host, 'example.test');
  });
}
