import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../domain/note_models.dart';

/// Conteúdo coletado no editor.
class NoteDraft {
  const NoteDraft({
    required this.content,
    this.title,
    this.sensitivity = SensitivityLevel.publico,
  });

  final String? title;
  final String content;
  final SensitivityLevel sensitivity;
}

/// Abre o editor de nota. O salvamento acontece dentro do modal: enquanto a
/// API não confirma, o texto continua na tela e o erro aparece no próprio
/// formulário. Devolve `true` quando a nota foi salva.
Future<bool> showNoteEditorDialog(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required Future<ApiException?> Function(NoteDraft draft) onSubmit,
  Note? note,
}) async {
  final saved = await showAppDialog<bool>(
    context,
    title: title,
    closeLabel: AppStrings.close,
    maxWidth: 920,
    child: _NoteEditorBody(
      submitLabel: submitLabel,
      onSubmit: onSubmit,
      note: note,
    ),
  );
  return saved ?? false;
}

class _NoteEditorBody extends StatefulWidget {
  const _NoteEditorBody({
    required this.submitLabel,
    required this.onSubmit,
    this.note,
  });

  final String submitLabel;
  final Future<ApiException?> Function(NoteDraft draft) onSubmit;
  final Note? note;

  @override
  State<_NoteEditorBody> createState() => _NoteEditorBodyState();
}

class _NoteEditorBodyState extends State<_NoteEditorBody> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late SensitivityLevel _sensitivity;
  String? _contentError;
  String? _submitError;
  bool _isSaving = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _sensitivity = widget.note?.sensitivity ?? SensitivityLevel.publico;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _contentError = AppStrings.noteContentRequired);
      return;
    }
    final title = _titleController.text.trim();

    setState(() {
      _isSaving = true;
      _contentError = null;
      _submitError = null;
    });

    final error = await widget.onSubmit(
      NoteDraft(
        title: title.isEmpty ? null : title,
        content: content,
        sensitivity: _sensitivity,
      ),
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _isSaving = false;
        _submitError = error.message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleController,
          autofocus: !_isEditing,
          enabled: !_isSaving,
          textInputAction: TextInputAction.next,
          style: textTheme.titleMedium,
          decoration: const InputDecoration(
            labelText: AppStrings.noteTitleLabel,
            hintText: AppStrings.noteTitleHint,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        MarkdownEditor(
          controller: _contentController,
          enabled: !_isSaving,
          labels: MarkdownEditorLabels(
            label: AppStrings.noteContentLabel,
            hint: AppStrings.noteContentHint,
            emptyPreview: AppStrings.noteEditorEmptyPreview,
            edit: AppStrings.markdownEdit,
            done: AppStrings.markdownDone,
            commands: const {
              MarkdownCommand.heading: AppStrings.noteToolbarHeading,
              MarkdownCommand.bold: AppStrings.noteToolbarBold,
              MarkdownCommand.italic: AppStrings.noteToolbarItalic,
              MarkdownCommand.bulletList: AppStrings.noteToolbarList,
              MarkdownCommand.checklist: AppStrings.noteToolbarChecklist,
              MarkdownCommand.quote: AppStrings.noteToolbarQuote,
              MarkdownCommand.code: AppStrings.noteToolbarCode,
              MarkdownCommand.link: AppStrings.noteToolbarLink,
            },
            countLabel: AppStrings.noteCount,
          ),
        ),
        if (_contentError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _contentError!,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        SensitivitySelector(
          label: AppStrings.sensitivityNoteLabel,
          selected: _sensitivity,
          onChanged: _isSaving
              ? (_) {}
              : (level) => setState(() => _sensitivity = level),
        ),
        if (_submitError != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineMessage(
            message: _submitError!,
            variant: InlineMessageVariant.error,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            AppButton(
              label: widget.submitLabel,
              icon: Icons.check_rounded,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }
}
