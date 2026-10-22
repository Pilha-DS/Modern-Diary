import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/home/presentation/home_navigation.dart';
import 'package:modern_diary/src/features/life/domain/life_models.dart';
import 'package:modern_diary/src/features/life/presentation/life_graph_section.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_life_data_source.dart';

class _Harness {
  int? knowledgeId;
  int? goalId;
  int? noteId;
  DateTime? day;
  ToatController? toat;
}

Future<_Harness> _pumpSection(
  WidgetTester tester,
  FakeLifeDataSource source,
) async {
  tester.view.physicalSize = const Size(900, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final toat = ToatController();
  addTearDown(toat.dispose);
  final harness = _Harness();
  final navigation = HomeNavigation(
    openTag: (_) {},
    openGoal: (id) => harness.goalId = id,
    openKnowledgeItem: (id) => harness.knowledgeId = id,
    openNote: (id) => harness.noteId = id,
    openDay: (day) => harness.day = day,
    openSection: (_) {},
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LifeGraphSection(
            repository: source,
            toat: toat,
            navigation: navigation,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  harness.toat = toat;
  return harness;
}

void main() {
  testWidgets('sem registros mostra o estado vazio com o filtro', (
    tester,
  ) async {
    await _pumpSection(tester, FakeLifeDataSource());

    expect(find.text(AppStrings.liveGraphEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.liveGraphAllTypes), findsOneWidget);
    expect(find.text(AppStrings.liveGraphTab), findsNothing);
  });

  testWidgets('o filtro por tipo pede só aquele tipo ao back', (tester) async {
    final source = FakeLifeDataSource(
      nodes: [lifeNode(id: 'goal:1', type: LifeEntityType.goal, title: 'Meta')],
    );
    await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.auditEntityType('goal')));
    await tester.pumpAndSettle();

    expect(source.typeRequests.last, [LifeEntityType.goal]);

    await tester.tap(find.text(AppStrings.liveGraphAllTypes));
    await tester.pumpAndSettle();

    expect(source.typeRequests.last, isEmpty);
  });

  testWidgets('erro de carregamento oferece tentar novamente', (tester) async {
    final source = FakeLifeDataSource()
      ..error = const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Sem conexão.',
      );
    await _pumpSection(tester, source);

    expect(find.text(AppStrings.liveGraphErrorTitle), findsOneWidget);
    expect(find.text('Sem conexão.'), findsOneWidget);

    source.error = null;
    await tester.tap(find.text(AppStrings.liveGraphErrorRetry));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.liveGraphEmptyTitle), findsOneWidget);
  });

  testWidgets('a lista de conexões remove uma ligação manual', (tester) async {
    final source = FakeLifeDataSource(
      nodes: [
        lifeNode(id: 'note:1', type: LifeEntityType.note, title: 'Ideia'),
        lifeNode(id: 'goal:2', type: LifeEntityType.goal, title: 'Meta'),
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
    final harness = await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.liveGraphLinksButton));
    await tester.pumpAndSettle();

    expect(find.text('Meta ↔ Ideia'), findsOneWidget);

    await tester.tap(
      find.byTooltip(AppStrings.liveGraphRemoveLinkLabel('Meta', 'Ideia')),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.liveGraphRemoveLinkTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.liveGraphRemoveLinkAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(source.unlinkCalls, 1);
    expect(source.lastSource?.id, 'goal:2');
    expect(
      harness.toat?.messages.first.message,
      AppStrings.liveGraphLinkRemoved,
    );
    // Deixa o fechamento automático do TOAT acontecer antes do fim do teste.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('tocar num nó da meta abre a meta', (tester) async {
    final source = FakeLifeDataSource(
      nodes: [
        lifeNode(id: 'goal:42', type: LifeEntityType.goal, title: 'Meta'),
      ],
    );
    final harness = await _pumpSection(tester, source);

    final rect = tester.getRect(find.byType(NetworkGraph));
    for (var y = rect.top + 4; y < rect.bottom - 4; y += 20) {
      for (var x = rect.left + 4; x < rect.right - 4; x += 20) {
        await tester.tapAt(Offset(x, y));
        await tester.pump();
        if (harness.goalId != null) {
          break;
        }
      }
      if (harness.goalId != null) {
        break;
      }
    }

    expect(harness.goalId, 42);
  });
}
