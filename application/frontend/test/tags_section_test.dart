import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/tags/domain/tag_models.dart';
import 'package:modern_diary/src/features/tags/presentation/tags_section.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_tags_data_source.dart';

void main() {
  Future<void> pumpTags(WidgetTester tester, List<Tag> tags) async {
    tester.view.physicalSize = const Size(1100, 900);
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
            child: TagsSection(
              repository: FakeTagsDataSource(initial: tags),
              toat: toat,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('os cartões de tag ficam estreitos, com quatro por linha', (
    tester,
  ) async {
    await pumpTags(tester, const [
      Tag(id: 1, name: 'estudo', colorHex: '#2E7D5B', usageCount: 3),
      Tag(id: 2, name: 'foco', colorHex: '#4A7BA7', usageCount: 1),
      Tag(id: 3, name: 'saúde', colorHex: '#94670F', usageCount: 0),
      Tag(id: 4, name: 'leitura', colorHex: '#B3261E', usageCount: 2),
    ]);

    final cards = find.byType(AppSurface);
    expect(cards, findsNWidgets(4));

    final rects = [
      for (var index = 0; index < 4; index++) tester.getRect(cards.at(index)),
    ];
    // Largura estreita: cabem quatro cartões na mesma linha.
    expect(rects[1].top, rects[0].top);
    expect(rects[3].top, rects[0].top);
    expect(rects[0].width, lessThan(260));
  });

  testWidgets('o cartão de tag é alto e mantém o rodapé embaixo', (
    tester,
  ) async {
    await pumpTags(tester, const [
      Tag(id: 1, name: 'estudo', colorHex: '#2E7D5B', usageCount: 3),
      Tag(
        id: 2,
        name: 'foco',
        colorHex: '#4A7BA7',
        usageCount: 1,
        description: 'Conteúdo de estudo',
      ),
    ]);

    final cards = find.byType(AppSurface);
    final first = tester.getRect(cards.at(0));
    expect(first.height, greaterThanOrEqualTo(AppSpacing.xxl * 5));

    // O rodapé com o total de usos fica no fim do cartão, não colado no topo.
    final usageText = tester.getRect(find.text(AppStrings.tagUsageTotal(3)));
    expect(usageText.top, greaterThan(first.top + first.height / 2));
  });
}
