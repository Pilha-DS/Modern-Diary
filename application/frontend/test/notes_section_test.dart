import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/notes/domain/note_models.dart';
import 'package:modern_diary/src/features/notes/presentation/note_card.dart';
import 'package:modern_diary/src/features/notes/presentation/notes_section.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_notes_data_source.dart';

Note _note(int id, {String? title, String? content, bool isPinned = false}) {
  return Note(
    id: id,
    title: title ?? 'Nota $id',
    content: content ?? 'Anotação $id',
    isPinned: isPinned,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 20),
  );
}

Future<ToatController> _pumpSection(
  WidgetTester tester,
  FakeNotesDataSource source, {
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
          child: NotesSection(repository: source, toat: toat),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return toat;
}

void _dismissToat(ToatController toat) {
  for (final message in [...toat.messages]) {
    toat.dismiss(message.id);
  }
}

void main() {
  testWidgets('mostra o estado vazio e cria uma nota pelo editor', (
    tester,
  ) async {
    final source = FakeNotesDataSource();
    final toat = await _pumpSection(tester, source);

    expect(find.text(AppStrings.notesEmptyTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.newNote));
    await tester.pumpAndSettle();

    // O editor é único: título e conteúdo dentro do modal.
    final fields = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'Ideias');
    // O conteúdo nasce renderizado; o clique revela o markdown puro.
    await tester.tap(find.byType(MarkdownEditor));
    await tester.pumpAndSettle();
    await tester.enterText(fields.at(1), '# Projeto\n\n- [ ] estudar');

    await tester.tap(find.text(AppStrings.noteCreate));
    await tester.pumpAndSettle();

    expect(find.byType(NoteCard), findsOneWidget);
    expect(source.notes.single.title, 'Ideias');
    expect(source.notes.single.content, contains('# Projeto'));
    _dismissToat(toat);
  });

  testWidgets('a prévia do editor renderiza o markdown', (tester) async {
    final source = FakeNotesDataSource();
    await _pumpSection(tester, source, size: const Size(520, 1600));

    await tester.tap(find.text(AppStrings.newNote));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MarkdownEditor));
    await tester.pumpAndSettle();
    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .at(1),
      '## Receita\n\n**Farinha**',
    );
    await tester.tap(find.text(AppStrings.markdownDone));
    await tester.pumpAndSettle();

    expect(find.text('Receita', findRichText: true), findsOneWidget);
    expect(find.text('Farinha', findRichText: true), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
  });

  testWidgets('edita o conteúdo de uma nota', (tester) async {
    final source = FakeNotesDataSource(initial: [_note(1)]);
    final toat = await _pumpSection(tester, source);

    await tester.tap(find.byTooltip(AppStrings.editNote).first);
    await tester.pumpAndSettle();

    // A nota abre renderizada; clicar no texto revela o markdown puro.
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Anotação 1'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(MarkdownEditor));
    await tester.pumpAndSettle();

    await tester.enterText(
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextField))
          .at(1),
      'Texto revisado',
    );
    await tester.tap(find.text(AppStrings.noteSave));
    await tester.pumpAndSettle();

    expect(source.notes.single.content, 'Texto revisado');
    _dismissToat(toat);
  });

  testWidgets('fixa a nota e mostra o selo', (tester) async {
    final source = FakeNotesDataSource(initial: [_note(1)]);
    final toat = await _pumpSection(tester, source);

    await tester.tap(find.byTooltip(AppStrings.notePinAction).first);
    await tester.pumpAndSettle();

    expect(source.notes.single.isPinned, isTrue);
    expect(find.text(AppStrings.notePinnedBadge), findsOneWidget);
    _dismissToat(toat);
  });

  testWidgets('busca com debounce e filtra no back', (tester) async {
    final source = FakeNotesDataSource(
      initial: [
        _note(1, title: 'Receita', content: 'Farinha'),
        _note(2, title: 'Ideias', content: 'Comprar leite'),
      ],
    );
    await _pumpSection(tester, source);

    await tester.enterText(find.byType(TextField).first, 'farinha');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(source.lastQuery, 'farinha');
    expect(find.text('Receita'), findsOneWidget);
    expect(find.text('Ideias'), findsNothing);
  });

  testWidgets('exclui uma nota após confirmação', (tester) async {
    final source = FakeNotesDataSource(initial: [_note(1)]);
    final toat = await _pumpSection(tester, source);

    await tester.tap(find.byTooltip(AppStrings.noteDeleteAction).first);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.noteDeleteTitle), findsOneWidget);

    await tester.tap(find.text(AppStrings.noteDeleteAction));
    await tester.pumpAndSettle();

    expect(source.notes, isEmpty);
    expect(find.text(AppStrings.notesEmptyTitle), findsOneWidget);
    _dismissToat(toat);
  });
}
