import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../domain/knowledge_models.dart';

/// Leitura de um conhecimento: conteúdo em markdown, observações e anexos.
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
  Future<(KnowledgeObservation?, ApiException?)> Function(String text)?
  onAddObservation,
  Future<ApiException?> Function(KnowledgeObservation observation)?
  onRemoveObservation,
}) {
  return showAppDialog<void>(
    context,
    title: item.title,
    closeLabel: AppStrings.close,
    maxWidth: 620,
    child: _KnowledgeDetailBody(
      item: item,
      onContentChanged: onContentChanged,
      onAddObservation: onAddObservation,
      onRemoveObservation: onRemoveObservation,
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
    this.onAddObservation,
    this.onRemoveObservation,
  });

  final KnowledgeItem item;
  final ValueChanged<KnowledgeAttachment> onOpenAttachment;
  final ValueChanged<KnowledgeAttachment> onRemoveAttachment;
  final Future<ApiException?> Function(String content)? onContentChanged;
  final Future<(KnowledgeObservation?, ApiException?)> Function(String text)?
  onAddObservation;
  final Future<ApiException?> Function(KnowledgeObservation observation)?
  onRemoveObservation;

  @override
  State<_KnowledgeDetailBody> createState() => _KnowledgeDetailBodyState();
}

class _KnowledgeDetailBodyState extends State<_KnowledgeDetailBody> {
  late final TextEditingController _contentController;
  late final TextEditingController _observationController;
  late List<KnowledgeObservation> _observations;
  ApiException? _saveError;
  bool _isSaving = false;
  bool _isAddingObservation = false;
  bool _isSavingObservation = false;
  String? _observationError;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.item.content ?? '');
    _observationController = TextEditingController();
    _observations = [...widget.item.observations];
  }

  @override
  void dispose() {
    _contentController.dispose();
    _observationController.dispose();
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

  Future<void> _submitObservation() async {
    final add = widget.onAddObservation;
    final text = _observationController.text.trim();
    if (add == null || _isSavingObservation) {
      return;
    }
    if (text.isEmpty) {
      setState(() => _observationError = AppStrings.knowledgeObservationEmpty);
      return;
    }

    setState(() {
      _isSavingObservation = true;
      _observationError = null;
    });
    final (observation, error) = await add(text);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingObservation = false;
      _observationError = error?.message;
      if (observation != null) {
        _observations = [..._observations, observation];
        _isAddingObservation = false;
        _observationController.clear();
      }
    });
  }

  Future<void> _removeObservation(KnowledgeObservation observation) async {
    final remove = widget.onRemoveObservation;
    if (remove == null) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.knowledgeObservationDeleteTitle,
      message: AppStrings.knowledgeObservationPreview(observation.text),
      confirmLabel: AppStrings.knowledgeObservationDeleteConfirm,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.warning,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final error = await remove(observation);
    if (!mounted) {
      return;
    }
    setState(() {
      _observationError = error?.message;
      if (error == null) {
        _observations = [
          for (final kept in _observations)
            if (kept.id != observation.id) kept,
        ];
      }
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
        _observationsSection(context),
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

  Widget _observationsSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final canEdit = widget.onAddObservation != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.knowledgeObservationsTitle,
                style: textTheme.titleSmall,
              ),
            ),
            if (canEdit)
              AppButton(
                label: AppStrings.knowledgeAddObservation,
                icon: Icons.add_comment_outlined,
                variant: AppButtonVariant.ghost,
                onPressed: _isAddingObservation || _isSavingObservation
                    ? null
                    : () => setState(() {
                        _isAddingObservation = true;
                        _observationError = null;
                      }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_isAddingObservation) ...[
          AppTextArea(
            controller: _observationController,
            hint: AppStrings.knowledgeObservationHint,
            minLines: 3,
            maxLines: 6,
            enabled: !_isSavingObservation,
            errorText: _observationError,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: _isSavingObservation
                    ? null
                    : () => setState(() {
                        _isAddingObservation = false;
                        _observationError = null;
                        _observationController.clear();
                      }),
                child: const Text(AppStrings.cancel),
              ),
              AppButton(
                label: AppStrings.save,
                icon: Icons.check_rounded,
                isLoading: _isSavingObservation,
                onPressed: _isSavingObservation ? null : _submitObservation,
              ),
            ],
          ),
        ] else if (_observations.isEmpty)
          Text(
            AppStrings.knowledgeNoObservations,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final observation in _observations)
                _ObservationTile(
                  observation: observation,
                  onRemove: widget.onRemoveObservation == null
                      ? null
                      : () => _removeObservation(observation),
                ),
            ],
          ),
        if (_observationError != null && !_isAddingObservation) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineMessage(
            message: _observationError!,
            variant: InlineMessageVariant.error,
          ),
        ],
      ],
    );
  }
}

/// Uma observação do conhecimento: texto, data e remoção.
class _ObservationTile extends StatelessWidget {
  const _ObservationTile({required this.observation, this.onRemove});

  final KnowledgeObservation observation;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        elevated: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(observation.text, style: textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.knowledgeObservationCreatedAt(
                      observation.createdAt.toLocal(),
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: AppStrings.knowledgeRemoveObservationLabel(
                  AppStrings.knowledgeObservationPreview(observation.text),
                ),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
