import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/knowledge/domain/knowledge_models.dart';
import 'package:modern_diary/src/features/knowledge/presentation/knowledge_card.dart';
import 'package:modern_diary/src/features/knowledge/presentation/knowledge_section.dart';
import 'package:modern_diary/src/features/tags/domain/tag_models.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import 'support/fake_goals_data_source.dart';
import 'support/fake_knowledge_data_source.dart';
import 'support/fake_tags_data_source.dart';

KnowledgeItem _item(
  int id, {
  List<KnowledgeReference> relations = const [],
  List<KnowledgeExternalLink> links = const [],
  List<Tag> tags = const [],
  SensitivityLevel sensitivity = SensitivityLevel.publico,
}) {
  return KnowledgeItem(
    id: id,
    title: 'Conhecimento $id',
    content: 'Anotação sobre o tema $id',
    links: links,
    relations: relations,
    tags: tags,
    attachments: const [],
    sensitivity: sensitivity,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  );
}

Future<ToatController> _pumpSection(
  WidgetTester tester,
  FakeKnowledgeDataSource source, {
  Size size = const Size(1200, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final toat = ToatController();
  addTearDown(toat.dispose);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        backgroundColor: AppColors.grayLight,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: KnowledgeSection(
            repository: source,
            tagsRepository: FakeTagsDataSource(),
            goalsRepository: FakeGoalsDataSource(),
            toat: toat,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return toat;
}

void main() {
  testWidgets('abre em lista e permite trocar para o grafo', (tester) async {
    final source = FakeKnowledgeDataSource(initial: [_item(1), _item(2)]);
    await _pumpSection(tester, source);

    expect(find.byType(KnowledgeCard), findsNWidgets(2));
    expect(find.byType(NetworkGraph), findsNothing);

    await tester.tap(find.text(AppStrings.knowledgeViewGraph));
    await tester.pumpAndSettle();

    expect(find.byType(NetworkGraph), findsOneWidget);
    expect(find.byType(KnowledgeCard), findsNothing);
    expect(source.graphCalls, 1);

    await tester.tap(find.text(AppStrings.knowledgeViewList));
    await tester.pumpAndSettle();

    expect(find.byType(KnowledgeCard), findsNWidgets(2));
  });

  testWidgets('filtra o grafo pela tag escolhida', (tester) async {
    const study = Tag(
      id: 7,
      name: 'estudo',
      colorHex: '#2E7D5B',
      usageCount: 1,
    );
    final source = FakeKnowledgeDataSource(
      initial: [
        _item(1, tags: const [study]),
        _item(2),
      ],
    );
    final tagsSource = FakeTagsDataSource(initial: const [study]);
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final toat = ToatController();
    addTearDown(toat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: KnowledgeSection(
              repository: source,
              tagsRepository: tagsSource,
              goalsRepository: FakeGoalsDataSource(),
              toat: toat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.knowledgeViewGraph));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkGraph), findsOneWidget);
    expect(source.graphCalls, 1);

    // O filtro por tag vale para o grafo: o servidor recebe a tag.
    await tester.tap(find.widgetWithText(AppChip, 'estudo'));
    await tester.pumpAndSettle();

    expect(source.graphCalls, 2);
    expect(source.lastGraphTagId, 7);
  });

  testWidgets('o nó do grafo abre um mini-modal com os dados do conhecimento', (
    tester,
  ) async {
    const study = Tag(
      id: 7,
      name: 'estudo',
      colorHex: '#2E7D5B',
      usageCount: 1,
    );
    final source = FakeKnowledgeDataSource(
      initial: [
        _item(1, tags: const [study], sensitivity: SensitivityLevel.sigiloso),
      ],
    );
    await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.knowledgeViewGraph));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.knowledgeNodeOpenHint), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    // Com um nó só, ele fica no centro da área do grafo.
    await mouse.moveTo(tester.getCenter(find.byType(NetworkGraph)));
    await tester.pump(AppDurations.hoverTooltip);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.knowledgeNodeOpenHint), findsOneWidget);
    expect(find.text(AppStrings.knowledgeRelationsCount(0)), findsOneWidget);
    expect(
      find.text(
        AppStrings.sensitivityLabelOf(SensitivityLevel.sigiloso.apiValue),
      ),
      findsWidgets,
    );
    expect(find.text('estudo'), findsWidgets);

    await mouse.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.knowledgeNodeOpenHint), findsNothing);
  });

  testWidgets('mostra o estado vazio quando não há conhecimentos', (
    tester,
  ) async {
    await _pumpSection(tester, FakeKnowledgeDataSource());

    expect(find.text(AppStrings.knowledgeEmptyTitle), findsOneWidget);
    expect(find.byType(KnowledgeCard), findsNothing);
  });

  testWidgets('cria um conhecimento pelo formulário', (tester) async {
    final source = FakeKnowledgeDataSource();
    final toat = await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.newKnowledge));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Índice no banco');
    await tester.tap(find.text(AppStrings.knowledgeCreate));
    await tester.pumpAndSettle();

    expect(find.byType(KnowledgeCard), findsOneWidget);
    expect(find.text('Índice no banco'), findsOneWidget);
    expect(source.items.single.title, 'Índice no banco');

    for (final message in [...toat.messages]) {
      toat.dismiss(message.id);
    }
  });

  testWidgets('cartão mostra a grade compacta e cada coleção abre em modal', (
    tester,
  ) async {
    final source = FakeKnowledgeDataSource(
      initial: [
        _item(
          1,
          relations: const [KnowledgeReference(id: 2, title: 'Outro')],
          links: const [
            KnowledgeExternalLink(url: 'https://example.com', label: 'Exemplo'),
          ],
        ),
        _item(2),
      ],
    );
    await _pumpSection(tester, source);

    expect(find.text(AppStrings.knowledgeGoalsCell), findsNWidgets(2));
    expect(find.text(AppStrings.knowledgeLinksCell), findsNWidgets(2));
    expect(find.text(AppStrings.knowledgeConnectionsCell), findsNWidgets(2));
    expect(find.text(AppStrings.knowledgeQuantityLabel), findsNWidgets(2));
    expect(
      find.text(AppStrings.shortDate(DateTime(2026, 10, 20))),
      findsWidgets,
    );

    await tester.tap(find.text(AppStrings.knowledgeLinksCell).first);
    await tester.pumpAndSettle();

    expect(find.text('Exemplo'), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.close));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.knowledgeConnectionsCell).first);
    await tester.pumpAndSettle();

    expect(find.text('Outro'), findsOneWidget);
  });

  testWidgets('cartão mostra o nível de sensibilidade do conhecimento', (
    tester,
  ) async {
    final source = FakeKnowledgeDataSource(
      initial: [
        _item(1, sensitivity: SensitivityLevel.sigiloso),
        _item(2, sensitivity: SensitivityLevel.basico),
      ],
    );
    await _pumpSection(tester, source);

    expect(find.text(AppStrings.sensitivitySecret), findsOneWidget);
    expect(find.text(AppStrings.sensitivityBasic), findsOneWidget);
    expect(find.text(AppStrings.sensitivityPublic), findsNothing);

    // O nível fica na mesma linha do nome do conhecimento.
    const title = 'Conhecimento 1';
    final titleRect = tester.getRect(find.text(title));
    final badgeRect = tester.getRect(
      find.ancestor(
        of: find.text(AppStrings.sensitivitySecret),
        matching: find.byType(AppChip),
      ),
    );
    expect(badgeRect.left, greaterThan(titleRect.right - 1));
    expect(badgeRect.center.dy, closeTo(titleRect.center.dy, 24));
  });

  testWidgets('cria um conhecimento no nível escolhido', (tester) async {
    final source = FakeKnowledgeDataSource();
    final toat = await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.newKnowledge));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Integração');
    await tester.tap(find.text(AppStrings.sensitivitySecret));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.knowledgeCreate));
    await tester.pumpAndSettle();

    expect(source.items.single.sensitivity, SensitivityLevel.sigiloso);
    expect(find.text(AppStrings.sensitivitySecret), findsOneWidget);

    for (final message in [...toat.messages]) {
      toat.dismiss(message.id);
    }
  });

  testWidgets('cartões estreitos e altos ocupam quatro colunas por linha', (
    tester,
  ) async {
    final source = FakeKnowledgeDataSource(
      initial: [for (var id = 1; id <= 5; id++) _item(id)],
    );
    await _pumpSection(tester, source, size: const Size(930, 2000));

    final cards = find.byType(KnowledgeCard);
    expect(cards, findsNWidgets(5));

    final firstRowTop = tester.getTopLeft(cards.at(0)).dy;
    for (var index = 1; index < 4; index++) {
      expect(tester.getTopLeft(cards.at(index)).dy, firstRowTop);
    }
    expect(tester.getTopLeft(cards.at(4)).dy, greaterThan(firstRowTop));

    final cardSize = tester.getSize(cards.first);
    expect(cardSize.width, lessThan(250));
    expect(cardSize.height, greaterThan(cardSize.width * 1.5));
  });

  testWidgets('cartões da mesma linha têm a mesma altura', (tester) async {
    final source = FakeKnowledgeDataSource(
      initial: [
        _item(
          1,
          tags: const [
            Tag(id: 1, name: 'dawkdinaoiw', colorHex: '#22AA66', usageCount: 1),
            Tag(id: 2, name: 'dwad', colorHex: '#3366CC', usageCount: 1),
          ],
          links: const [
            KnowledgeExternalLink(url: 'https://example.com', label: 'Exemplo'),
          ],
          relations: const [KnowledgeReference(id: 2, title: 'Outro')],
        ),
        _item(2),
        _item(
          3,
          relations: const [
            KnowledgeReference(id: 4, title: 'Um'),
            KnowledgeReference(id: 5, title: 'Dois'),
          ],
        ),
      ],
    );
    await _pumpSection(tester, source, size: const Size(1200, 1800));

    final cards = find.byType(KnowledgeCard);
    expect(cards, findsNWidgets(3));

    final firstSize = tester.getSize(cards.at(0));
    for (var index = 1; index < 3; index++) {
      final size = tester.getSize(cards.at(index));
      expect(
        tester.getTopLeft(cards.at(index)).dy,
        tester.getTopLeft(cards.at(0)).dy,
      );
      expect(size.height, firstSize.height);
      expect(size.width, firstSize.width);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('em janela estreita o cartão ocupa a linha sem estourar', (
    tester,
  ) async {
    final source = FakeKnowledgeDataSource(initial: [_item(1), _item(2)]);
    await _pumpSection(tester, source, size: const Size(420, 1600));

    final cards = find.byType(KnowledgeCard);
    expect(cards, findsNWidgets(2));

    final cardSize = tester.getSize(cards.first);
    expect(cardSize.width, greaterThan(340));
    expect(tester.takeException(), isNull);
  });
}
