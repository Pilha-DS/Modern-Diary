import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart' hide SensitivityBadge, SensitivitySelector;

import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../../tags/data/tags_repository.dart';
import '../../tags/domain/tag_models.dart';
import '../../tags/presentation/tag_chips.dart';
import '../../tags/presentation/tag_picker.dart';
import '../domain/knowledge_models.dart';

const int maxAttachmentBytes = 5 * 1024 * 1024;

/// Dados coletados no formulário de conhecimento.
class KnowledgeDraft {
  const KnowledgeDraft({
    required this.title,
    this.content,
    this.links = const [],
    this.files = const [],
    this.tags = const [],
    this.sensitivity = SensitivityLevel.publico,
  });

  final String title;
  final String? content;
  final List<KnowledgeExternalLink> links;
  final List<KnowledgeUploadFile> files;
  final List<Tag> tags;
  final SensitivityLevel sensitivity;
}

Future<KnowledgeDraft?> showKnowledgeFormDialog(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required TagsDataSource tagsSource,
  KnowledgeItem? item,
}) {
  return showAppDialog<KnowledgeDraft>(
    context,
    title: title,
    closeLabel: AppStrings.close,
    maxWidth: 620,
    child: _KnowledgeFormBody(
      submitLabel: submitLabel,
      tagsSource: tagsSource,
      item: item,
    ),
  );
}

class _KnowledgeFormBody extends StatefulWidget {
  const _KnowledgeFormBody({
    required this.submitLabel,
    required this.tagsSource,
    this.item,
  });

  final String submitLabel;
  final TagsDataSource tagsSource;
  final KnowledgeItem? item;

  @override
  State<_KnowledgeFormBody> createState() => _KnowledgeFormBodyState();
}

class _LinkRow {
  _LinkRow({String? url, String? label})
    : urlController = TextEditingController(text: url ?? ''),
      labelController = TextEditingController(text: label ?? '');

  final TextEditingController urlController;
  final TextEditingController labelController;

  void dispose() {
    urlController.dispose();
    labelController.dispose();
  }
}

class _KnowledgeFormBodyState extends State<_KnowledgeFormBody> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final List<_LinkRow> _linkRows = [];
  final List<KnowledgeUploadFile> _files = [];
  late List<Tag> _tags;
  late SensitivityLevel _sensitivity;
  String? _titleError;
  String? _linksError;
  String? _filesError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _contentController = TextEditingController(
      text: widget.item?.content ?? '',
    );
    for (final link in widget.item?.links ?? const <KnowledgeExternalLink>[]) {
      _linkRows.add(_LinkRow(url: link.url, label: link.label));
    }
    _tags = [...?widget.item?.tags];
    _sensitivity = widget.item?.sensitivity ?? SensitivityLevel.publico;
  }

  Future<void> _pickTags() async {
    final picked = await showTagPicker(
      context,
      dataSource: widget.tagsSource,
      selected: _tags,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _tags = picked);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    for (final row in _linkRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addLinkRow() {
    setState(() => _linkRows.add(_LinkRow()));
  }

  void _removeLinkRow(int index) {
    final row = _linkRows.removeAt(index);
    row.dispose();
    setState(() {});
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) {
        return;
      }

      final picked = <KnowledgeUploadFile>[];
      var tooLarge = false;
      for (final platformFile in result.files) {
        final bytes = platformFile.bytes;
        if (bytes == null) {
          continue;
        }
        if (bytes.length > maxAttachmentBytes) {
          tooLarge = true;
          continue;
        }
        picked.add(
          KnowledgeUploadFile(
            filename: platformFile.name,
            bytes: bytes,
            contentType: _contentTypeFor(platformFile.name),
          ),
        );
      }

      setState(() {
        _files.addAll(picked);
        _filesError = tooLarge ? AppStrings.knowledgeFileTooLarge : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _filesError = AppStrings.knowledgeAttachmentFailed);
      }
    }
  }

  void _removeFile(int index) {
    setState(() => _files.removeAt(index));
  }

  void _submit() {
    final title = _titleController.text.trim();
    var hasInvalidLink = false;
    final links = <KnowledgeExternalLink>[];

    for (final row in _linkRows) {
      final url = row.urlController.text.trim();
      if (url.isEmpty) {
        continue;
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        hasInvalidLink = true;
        continue;
      }
      final label = row.labelController.text.trim();
      links.add(
        KnowledgeExternalLink(url: url, label: label.isEmpty ? null : label),
      );
    }

    setState(() {
      _titleError = title.isEmpty ? AppStrings.knowledgeTitleRequired : null;
      _linksError = hasInvalidLink ? AppStrings.knowledgeInvalidLink : null;
    });

    if (_titleError != null || _linksError != null) {
      return;
    }

    final content = _contentController.text.trim();
    Navigator.of(context).pop(
      KnowledgeDraft(
        title: title,
        content: content.isEmpty ? null : content,
        links: links,
        files: List.unmodifiable(_files),
        tags: _tags,
        sensitivity: _sensitivity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: AppStrings.knowledgeTitleLabel,
            hintText: AppStrings.knowledgeTitleHint,
            errorText: _titleError,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        MarkdownEditor(
          controller: _contentController,
          labels: MarkdownEditorLabels(
            label: AppStrings.knowledgeContentLabel,
            hint: AppStrings.knowledgeContentHint,
            emptyPreview: AppStrings.markdownEmptyPreview,
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
        const SizedBox(height: AppSpacing.md),
        SensitivitySelector(
          label: AppStrings.sensitivityKnowledgeLabel,
          selected: _sensitivity,
          onChanged: (level) => setState(() => _sensitivity = level),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_tags.isNotEmpty) ...[
          TagChips(
            tags: _tags,
            onRemove: (tag) {
              setState(
                () => _tags = [
                  for (final kept in _tags)
                    if (kept.id != tag.id) kept,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: AppStrings.tagPickerAdd,
            icon: Icons.sell_outlined,
            variant: AppButtonVariant.ghost,
            onPressed: _pickTags,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.knowledgeLinksLabel,
                style: textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: AppStrings.knowledgeAddLink,
              onPressed: _addLinkRow,
              icon: const Icon(Icons.add_link_rounded),
            ),
          ],
        ),
        if (_linksError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              _linksError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        for (var index = 0; index < _linkRows.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _linkRows[index].urlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: AppStrings.knowledgeLinkUrlLabel,
                    hintText: AppStrings.knowledgeLinkUrlHint,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _linkRows[index].labelController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: AppStrings.knowledgeLinkLabel,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppStrings.delete,
                onPressed: () => _removeLinkRow(index),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.knowledgeAttachmentsLabel,
                style: textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: AppStrings.knowledgePickFiles,
              onPressed: _pickFiles,
              icon: const Icon(Icons.attach_file_rounded),
            ),
          ],
        ),
        if (_filesError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              _filesError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        if (_files.isNotEmpty)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (var index = 0; index < _files.length; index++)
                AppChip(
                  icon: Icons.attach_file_rounded,
                  label: _files[index].filename,
                  deleteLabel: AppStrings.knowledgeRemoveAttachmentLabel(
                    _files[index].filename,
                  ),
                  onDeleted: () => _removeFile(index),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.cancel),
            ),
            AppButton(
              label: widget.submitLabel,
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}

String _contentTypeFor(String filename) {
  final extension = filename.contains('.')
      ? filename.split('.').last.toLowerCase()
      : '';
  return switch (extension) {
    'txt' || 'md' => 'text/plain',
    'csv' => 'text/csv',
    'json' => 'application/json',
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'svg' => 'image/svg+xml',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };
}
