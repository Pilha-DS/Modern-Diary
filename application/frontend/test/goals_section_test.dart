import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/goals/domain/goal_models.dart';
import 'package:modern_diary/src/features/goals/presentation/goal_card.dart';
import 'package:modern_diary/src/features/goals/presentation/goals_section.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_goals_data_source.dart';
import 'support/fake_tags_data_source.dart';

void main() {
  testWidgets('mostra três metas por linha e cria uma meta pelo formulário', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final source = FakeGoalsDataSource(
      initial: [
        for (var index = 0; index < 4; index++)
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
    final toat = ToatController();
    addTearDown(toat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: GoalsSection(
              repository: source,
              tagsRepository: FakeTagsDataSource(),
              toat: toat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoalCard), findsNWidgets(4));
    expect(find.text(AppStrings.sensitivityPublic), findsNWidgets(4));
    final cards = find.byType(GoalCard);
    final firstRowTop = tester.getTopLeft(cards.at(0)).dy;
    expect(tester.getTopLeft(cards.at(2)).dy, firstRowTop);
    expect(tester.getTopLeft(cards.at(3)).dy, greaterThan(firstRowTop));

    await tester.tap(find.text(AppStrings.newGoal));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.goalTitleLabel), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Minha meta');
    await tester.tap(find.text(AppStrings.sensitivityComplex));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.goalCreate));
    await tester.pumpAndSettle();

    expect(find.byType(GoalCard), findsNWidgets(5));
    expect(find.text('Minha meta'), findsOneWidget);
    expect(source.goals.last.sensitivity, SensitivityLevel.complexo);
    expect(find.text(AppStrings.sensitivityComplex), findsOneWidget);

    for (final message in [...toat.messages]) {
      toat.dismiss(message.id);
    }
  });
}
