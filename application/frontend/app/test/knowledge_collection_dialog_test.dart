import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/features/knowledge/presentation/knowledge_collection_dialog.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

void main() {
  testWidgets('modal lista, adiciona e remove sem fechar', (tester) async {
    var entries = <String>['Primeira meta'];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: AppButton(
                label: 'Abrir',
                onPressed: () => showKnowledgeCollectionDialog<String>(
                  context: context,
                  title: 'Metas',
                  entries: entries,
                  icon: Icons.flag_outlined,
                  emptyMessage: 'Nenhuma meta.',
                  addLabel: 'Ligar meta',
                  labelOf: (entry) => entry,
                  removeLabelOf: (entry) => 'Remover $entry',
                  onAdd: (current) async {
                    final added = 'Meta ${current.length + 1}';
                    entries = [...current, added];
                    return added;
                  },
                  onRemove: (entry, current) async {
                    entries = [
                      for (final kept in current)
                        if (kept != entry) kept,
                    ];
                    return true;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Primeira meta'), findsOneWidget);

    await tester.tap(find.text('Ligar meta'));
    await tester.pumpAndSettle();

    expect(find.text('Primeira meta'), findsOneWidget);
    expect(find.text('Meta 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover Primeira meta'));
    await tester.pumpAndSettle();

    expect(find.text('Primeira meta'), findsNothing);
    expect(find.text('Meta 2'), findsOneWidget);
  });
}
