import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/features/goals/domain/goal_models.dart';
import 'package:modern_diary/src/features/goals/presentation/goals_controller.dart';

import 'support/fake_goals_data_source.dart';

void main() {
  test(
    'carrega doze metas por página e busca o restante sob demanda',
    () async {
      final source = FakeGoalsDataSource(
        initial: [
          for (var index = 0; index < 14; index++)
            Goal(
              id: index + 1,
              title: 'Meta $index',
              isCompleted: false,
              isArchived: false,
              progressDone: 0,
              progressTotal: 1,
              steps: const [],
            ),
        ],
      );
      final controller = GoalsController(source);

      await controller.loadFirstPage();

      expect(controller.goals.length, 12);
      expect(controller.total, 14);
      expect(controller.hasMore, isTrue);
      expect(controller.countFor(GoalFilter.active), 14);

      await controller.loadMore();

      expect(controller.goals.length, 14);
      expect(controller.hasMore, isFalse);
      controller.dispose();
    },
  );

  test('filtra por situação mantendo os contadores do back', () async {
    final source = FakeGoalsDataSource(
      initial: [
        Goal(
          id: 1,
          title: 'Ativa',
          isCompleted: false,
          isArchived: false,
          progressDone: 1,
          progressTotal: 2,
          steps: const [],
        ),
        Goal(
          id: 2,
          title: 'Concluída',
          isCompleted: true,
          isArchived: false,
          progressDone: 1,
          progressTotal: 1,
          steps: const [],
        ),
        Goal(
          id: 3,
          title: 'Arquivada',
          isCompleted: false,
          isArchived: true,
          progressDone: 0,
          progressTotal: 1,
          steps: const [],
        ),
      ],
    );
    final controller = GoalsController(source);
    await controller.loadFirstPage();

    expect(controller.goals.single.title, 'Ativa');
    expect(controller.countFor(GoalFilter.completed), 1);
    expect(controller.countFor(GoalFilter.archived), 1);

    await controller.setFilter(GoalFilter.archived);

    expect(controller.filter, GoalFilter.archived);
    expect(controller.goals.single.title, 'Arquivada');
    controller.dispose();
  });

  test('cria, conclui, arquiva e exclui atualizando a lista', () async {
    final controller = GoalsController(FakeGoalsDataSource());
    await controller.loadFirstPage();

    expect(
      await controller.createGoal(
        title: 'Aprender Flutter',
        steps: ['Instalar'],
      ),
      isNull,
    );
    final goal = controller.goals.single;
    expect(goal.title, 'Aprender Flutter');
    expect(goal.progressTotal, 1);

    expect(await controller.setCompleted(goal.id, completed: true), isNull);
    expect(controller.goals, isEmpty);
    expect(controller.countFor(GoalFilter.completed), 1);

    await controller.setFilter(GoalFilter.completed);
    expect(controller.goals.single.isCompleted, isTrue);

    expect(
      await controller.setArchived(controller.goals.single.id, archived: true),
      isNull,
    );
    expect(controller.goals, isEmpty);
    expect(controller.countFor(GoalFilter.archived), 1);

    await controller.setFilter(GoalFilter.archived);
    expect(await controller.deleteGoal(controller.goals.single.id), isNull);
    expect(controller.goals, isEmpty);
    expect(controller.countFor(GoalFilter.archived), 0);
    controller.dispose();
  });

  test('etapa concluída muda o progresso da meta', () async {
    final controller = GoalsController(FakeGoalsDataSource());
    await controller.loadFirstPage();
    await controller.createGoal(title: 'Meta', steps: ['Um', 'Dois']);

    final goal = controller.goals.single;
    expect(goal.progressDone, 0);
    expect(goal.progressTotal, 2);

    final error = await controller.toggleStep(goal.id, goal.steps.first);

    expect(error, isNull);
    expect(controller.goals.single.progressDone, 1);
    expect(controller.goals.single.steps.first.isDone, isTrue);
    controller.dispose();
  });
}
