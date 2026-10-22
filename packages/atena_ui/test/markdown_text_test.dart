import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atena_ui/atena_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('renderiza título, negrito e itálico', (tester) async {
    await tester.pumpWidget(
      _wrap(const MarkdownText('# Meu dia\n\nFoi **produtivo** e *leve*.')),
    );

    expect(find.text('Meu dia', findRichText: true), findsOneWidget);
    expect(
      find.text('Foi produtivo e leve.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('renderiza checklist concluído', (tester) async {
    await tester.pumpWidget(
      _wrap(const MarkdownText('- [x] Estudar\n- [ ] Correr')),
    );

    expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_box_outline_blank_rounded), findsOneWidget);
  });

  testWidgets('texto vazio usa a mensagem de vazio', (tester) async {
    await tester.pumpWidget(
      _wrap(const MarkdownText('   ', emptyText: 'Nenhuma nota.')),
    );

    expect(find.text('Nenhuma nota.'), findsOneWidget);
  });

  testWidgets('nasce renderizado e vira texto puro ao clicar', (tester) async {
    final controller = TextEditingController(text: '**Forte**');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        MarkdownEditor(
          controller: controller,
          labels: const MarkdownEditorLabels(
            emptyPreview: 'Nada para ver.',
            edit: 'Clique para editar',
            done: 'Concluir edição',
          ),
        ),
      ),
    );

    expect(find.text('Forte', findRichText: true), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Forte', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, '**Forte**');
  });

  testWidgets('sair da edição volta a renderizar e avisa o texto novo', (
    tester,
  ) async {
    final controller = TextEditingController(text: '# Título');
    addTearDown(controller.dispose);
    final completed = <String>[];

    await tester.pumpWidget(
      _wrap(
        MarkdownEditor(
          controller: controller,
          labels: const MarkdownEditorLabels(
            emptyPreview: 'Nada para ver.',
            edit: 'Clique para editar',
            done: 'Concluir edição',
          ),
          onEditingComplete: completed.add,
        ),
      ),
    );

    await tester.tap(find.text('Título', findRichText: true));
    await tester.pumpAndSettle();
    controller.text = '**Novo**';
    await tester.tap(find.text('Concluir edição'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Novo', findRichText: true), findsOneWidget);
    expect(completed, ['**Novo**']);
  });

  testWidgets('a barra de formatação envolve a seleção', (tester) async {
    final controller = TextEditingController(text: 'texto');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        MarkdownEditor(
          controller: controller,
          labels: const MarkdownEditorLabels(
            emptyPreview: 'Nada para ver.',
            edit: 'Clique para editar',
            done: 'Concluir edição',
            commands: {MarkdownCommand.bold: 'Negrito'},
          ),
        ),
      ),
    );

    await tester.tap(find.text('texto', findRichText: true));
    await tester.pumpAndSettle();
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.tap(find.byTooltip('Negrito'));
    await tester.pump();

    expect(controller.text, '**texto**');
    expect(find.byType(TextField), findsOneWidget);
  });
}
