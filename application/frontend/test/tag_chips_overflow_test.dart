import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/tags/domain/tag_models.dart';
import 'package:modern_diary/src/features/tags/presentation/tag_chips.dart';
import 'package:atena_ui/atena_ui.dart';

Tag _tag(int id) {
  return Tag(id: id, name: 'tag$id', colorHex: '#22C55E', usageCount: 0);
}

Future<void> _pump(
  WidgetTester tester,
  double width,
  List<Tag> tags, {
  VoidCallback? onShowAll,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: TagChipsOverflow(tags: tags, onShowAll: onShowAll),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra só as tags que cabem e resume o resto em Ver mais', (
    tester,
  ) async {
    final tags = [for (var index = 1; index <= 6; index++) _tag(index)];
    var showsAll = 0;

    await _pump(tester, 220, tags, onShowAll: () => showsAll++);

    expect(find.text(tags.first.name), findsOneWidget);
    expect(find.text(tags.last.name), findsNothing);
    expect(find.text(AppStrings.knowledgeTagsShowAll), findsOneWidget);

    await tester.tap(find.text(AppStrings.knowledgeTagsShowAll));
    expect(showsAll, 1);
  });

  testWidgets('quando todas cabem, não aparece Ver mais', (tester) async {
    await _pump(tester, 600, [_tag(1), _tag(2)]);

    expect(find.text(_tag(1).name), findsOneWidget);
    expect(find.text(_tag(2).name), findsOneWidget);
    expect(find.text(AppStrings.knowledgeTagsShowAll), findsNothing);
  });
}
