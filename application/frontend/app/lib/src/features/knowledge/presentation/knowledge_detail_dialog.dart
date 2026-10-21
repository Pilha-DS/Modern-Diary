import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../domain/knowledge_models.dart';

/// Leitura de um conhecimento: conteúdo em markdown e anexos.
///
/// O conteúdo aparece renderizado e vira texto puro ao ser clicado. Ao sair,
/// volta a renderizar e o texto novo é salvo por [onContentChanged].
///
/// Metas, links, conexões e tags ficam no cartão, cada um no seu modal.
Future<void> showKnowledgeDetailDialog(
  BuildContext context, {
  required KnowledgeItem item,
  required ValueChanged<KnowledgeAttachment> onOpenAttachment,
  required ValueChanged<KnowledgeAttachment> onRemoveAttachment,
  Future<ApiException?> Function(String content)? onContentChanged,
}) {
  return showAppDialog<void>(
    context,
    title: item.title,
    closeLabel: AppStrings.close,
    maxWidth: 620,
    child: _KnowledgeDetailBody(
      item: item,
      onContentChanged: onContentChanged,
      onOpenAttachment: onOpenAttachment,
      onRemoveAttachment: onRemoveAttachment,
    ),
  );
}

class _KnowledgeDetailBody extends StatefulWidget {
  const _KnowledgeDetailBody({
    required this.item,
    required this.onOpenAttachment,
    required this.onRemoveAttachment,
    this.onContentChanged,
  });

  final KnowledgeItem item;
  final ValueChanged<KnowledgeAttachment> onOpenAttachment;
  final ValueChanged<KnowledgeAttachment> onRemoveAttachment;
  final Future<ApiException?> Function(String content)? onContentChanged;

  @override
  State<_KnowledgeDetailBody> createState() => _KnowledgeDetailBodyState();
}

class _KnowledgeDetailBodyState extends State<_KnowledgeDetailBody> {
  late final TextEditingController _contentController;
  ApiException? _saveError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.item.content ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveContent(String content) async {
    final save = widget.onContentChanged;
    if (save == null || _isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    final error = await save(content);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _saveError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final canEdit = widget.onContentChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        MarkdownEditor(
          controller: _contentController,
          enabled: canEdit && !_isSaving,
          labels: MarkdownEditorLabels(
            hint: AppStrings.knowledgeContentHint,
            emptyPreview: AppStrings.knowledgeNoContent,
            edit: AppStrings.markdownEdit,
            done: AppStrings.markdownDone,
            commands: canEdit
                ? const {
                    MarkdownCommand.heading: AppStrings.noteToolbarHeading,
                    MarkdownCommand.bold: AppStrings.noteToolbarBold,
                    MarkdownCommand.italic: AppStrings.noteToolbarItalic,
                    MarkdownCommand.bulletList: AppStrings.noteToolbarList,
                    MarkdownCommand.checklist: AppStrings.noteToolbarChecklist,
                    MarkdownCommand.quote: AppStrings.noteToolbarQuote,
                    MarkdownCommand.code: AppStrings.noteToolbarCode,
                    MarkdownCommand.link: AppStrings.noteToolbarLink,
                  }
                : const {},
          ),
          onEditingComplete: _saveContent,
        ),
        if (_saveError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineMessage(
            message: _saveError!.message,
            variant: InlineMessageVariant.error,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isSaving
                  ? null
                  : () => _saveContent(_contentController.text),
              child: const Text(AppStrings.retry),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.knowledgeAttachmentsTitle, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (widget.item.attachments.isEmpty)
          Text(
            AppStrings.knowledgeNoAttachments,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final attachment in widget.item.attachments)
                AppChip(
                  icon: Icons.attach_file_rounded,
                  label:
                      '${attachment.filename} · '
                      '${AppStrings.knowledgeFileSize(attachment.sizeBytes)}',
                  semanticLabel: AppStrings.knowledgeOpenAttachmentLabel(
                    attachment.filename,
                  ),
                  onTap: () => widget.onOpenAttachment(attachment),
                  deleteLabel: AppStrings.knowledgeRemoveAttachmentLabel(
                    attachment.filename,
                  ),
                  onDeleted: () => widget.onRemoveAttachment(attachment),
                ),
            ],
          ),
      ],
    );
  }
}
