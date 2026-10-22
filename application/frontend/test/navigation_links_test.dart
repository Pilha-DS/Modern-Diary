import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/goals/domain/goal_models.dart';
import 'package:modern_diary/src/features/goals/presentation/goal_card.dart';
import 'package:modern_diary/src/features/goals/presentation/goals_section.dart';
import 'package:modern_diary/src/features/home/presentation/home_navigation.dart';
import 'package:modern_diary/src/features/knowledge/domain/knowledge_models.dart';
import 'package:modern_diary/src/features/knowledge/presentation/knowledge_card.dart';
import 'package:modern_diary/src/features/knowledge/presentation/knowledge_section.dart';
import 'package:modern_diary/src/features/tags/domain/tag_models.dart';
import 'package:modern_diary/src/features/tags/presentation/tags_section.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_goals_data_source.dart';
import 'support/fake_knowledge_data_source.dart';
import 'support/fake_tags_data_source.dart';

const _tag = Tag(id: 5, name: 'foco', colorHex: '#22C55E', usageCount: 2);

class _Recorder {
  Tag? tag;
  int? goalId;
  int? knowledgeId;
  DateTime? day;
  int? noteId;
  HomeSection? section;
  int focusHandled = 0;

  late final HomeNavigation navigation = HomeNavigation(
    openTag: (tag) => this.tag = tag,
    openGoal: (goalId) => this.goalId = goalId,
    openKnowledgeItem: (itemId) => knowledgeId = itemId,
    openNote: (noteId) => this.noteId = noteId,
    openDay: (day) => this.day = day,
    openSection: (section) => this.section = section,
  );
}

Goal _goal(int id, {List<Tag> tags = const []}) {
  return Goal(
    id: id,
    title: 'Meta $id',
    description: 'Descrição da meta $id',
    isCompleted: false,
    isArchived: false,
    progressDone: 1,
    progressTotal: 2,
    steps: const [
      GoalStep(id: 1, title: 'Primeira etapa', isDone: true, position: 1),
    ],
    tags: tags,
  );
}

KnowledgeItem _knowledge(int id, {List<Tag> tags = const []}) {
  return KnowledgeItem(
    id: id,
    title: 'Conhecimento $id',
    links: const [],
    relations: const [],
    attachments: const [],
    goals: const [KnowledgeGoalReference(id: 9, title: 'Meta 9')],
    tags: tags,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        backgroundColor: AppColors.grayLight,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('clicar na tag de uma meta abre a tag', (tester) async {
    final recorder = _Recorder();
    final toat = ToatController();
    addTearDown(toat.dispose);

    await _pump(
      tester,
      GoalsSection(
        repository: FakeGoalsDataSource(
          initial: [
            _goal(1, tags: const [_tag]),
          ],
        ),
        tagsRepository: FakeTagsDataSource(initial: const [_tag]),
        toat: toat,
        navigation: recorder.navigation,
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(GoalCard),
        matching: find.text(_tag.name),
      ),
    );
    await tester.pumpAndSettle();

    expect(recorder.tag?.id, _tag.id);
  });

  testWidgets('clicar na meta de um conhecimento abre a meta', (tester) async {
    final recorder = _Recorder();
    final toat = ToatController();
    addTearDown(toat.dispose);

    await _pump(
      tester,
      KnowledgeSection(
        repository: FakeKnowledgeDataSource(
          initial: [
            _knowledge(1, tags: const [_tag]),
          ],
        ),
        tagsRepository: FakeTagsDataSource(initial: const [_tag]),
        goalsRepository: FakeGoalsDataSource(initial: [_goal(9)]),
        toat: toat,
        navigation: recorder.navigation,
      ),
    );

    await tester.tap(find.text(AppStrings.knowledgeGoalsCell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meta 9'));
    await tester.pumpAndSettle();

    expect(recorder.goalId, 9);
  });

  testWidgets('clicar na tag de um conhecimento abre a tag', (tester) async {
    final recorder = _Recorder();
    final toat = ToatController();
    addTearDown(toat.dispose);

    await _pump(
      tester,
      KnowledgeSection(
        repository: FakeKnowledgeDataSource(
          initial: [
            _knowledge(1, tags: const [_tag]),
          ],
        ),
        tagsRepository: FakeTagsDataSource(initial: const [_tag]),
        goalsRepository: FakeGoalsDataSource(),
        toat: toat,
        navigation: recorder.navigation,
      ),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(KnowledgeCard),
        matching: find.text(_tag.name),
      ),
    );
    await tester.pumpAndSettle();

    expect(recorder.tag?.id, _tag.id);
  });

  testWidgets('abrir uma tag mostra os usos e cada uso leva ao registro', (
    tester,
  ) async {
    final recorder = _Recorder();
    final toat = ToatController();
    addTearDown(toat.dispose);

    final tagsSource = FakeTagsDataSource(
      initial: const [_tag],
      usages: [
        const TagUsage(
          targetType: TagTarget.knowledge,
          targetId: 42,
          title: 'Índice no banco',
        ),
        const TagUsage(
          targetType: TagTarget.goal,
          targetId: 9,
          title: 'Aprender Flutter',
        ),
        TagUsage(
          targetType: TagTarget.agendaDay,
          targetId: 0,
          day: DateTime(2026, 10, 20),
        ),
      ],
    );

    await _pump(
      tester,
      TagsSection(
        repository: tagsSource,
        toat: toat,
        navigation: recorder.navigation,
        focusTag: _tag,
        onFocusHandled: () => recorder.focusHandled++,
      ),
    );

    expect(recorder.focusHandled, 1);
    expect(find.text(AppStrings.tagUsageTitle(_tag.name)), findsOneWidget);

    await tester.tap(find.text('Índice no banco'));
    await tester.pumpAndSettle();

    expect(recorder.knowledgeId, 42);
    expect(find.text(AppStrings.tagUsageTitle(_tag.name)), findsNothing);
  });

  testWidgets('uso em um dia do mês abre o dia no calendário', (tester) async {
    final recorder = _Recorder();
    final toat = ToatController();
    addTearDown(toat.dispose);

    await _pump(
      tester,
      TagsSection(
        repository: FakeTagsDataSource(
          initial: const [_tag],
          usages: [
            TagUsage(
              targetType: TagTarget.agendaDay,
              targetId: 0,
              day: DateTime(2026, 10, 20),
            ),
          ],
        ),
        toat: toat,
        navigation: recorder.navigation,
        focusTag: _tag,
      ),
    );

    await tester.tap(find.text(AppStrings.fullDate(DateTime(2026, 10, 20))));
    await tester.pumpAndSettle();

    expect(recorder.day, DateTime(2026, 10, 20));
  });

  testWidgets('meta pedida por outra área abre nos detalhes', (tester) async {
    final recorder = _Recorder();
    final toat = ToatController();
    addTearDown(toat.dispose);

    await _pump(
      tester,
      GoalsSection(
        repository: FakeGoalsDataSource(initial: [_goal(9)]),
        tagsRepository: FakeTagsDataSource(),
        toat: toat,
        navigation: recorder.navigation,
        focusGoalId: 9,
        onFocusHandled: () => recorder.focusHandled++,
      ),
    );

    expect(recorder.focusHandled, 1);
    expect(find.text(AppStrings.goalDescriptionTitle), findsOneWidget);
    expect(find.text('Primeira etapa'), findsWidgets);
  });
}
