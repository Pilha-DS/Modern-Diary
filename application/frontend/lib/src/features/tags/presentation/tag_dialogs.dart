import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/tag_models.dart';

/// Dados coletados no formulário de tag.
class TagDraft {
  const TagDraft({
    required this.name,
    required this.colorHex,
    this.description,
  });

  final String name;
  final String colorHex;
  final String? description;
}

Future<TagDraft?> showTagFormDialog(
  BuildContext context, {
  required String title,
  required String submitLabel,
  Tag? tag,
  String? initialName,
}) {
  return showAppDialog<TagDraft>(
    context,
    title: title,
    closeLabel: AppStrings.close,
    maxWidth: 420,
    child: _TagFormBody(
      submitLabel: submitLabel,
      tag: tag,
      initialName: initialName,
    ),
  );
}

class _TagFormBody extends StatefulWidget {
  const _TagFormBody({required this.submitLabel, this.tag, this.initialName});

  final String submitLabel;
  final Tag? tag;
  final String? initialName;

  @override
  State<_TagFormBody> createState() => _TagFormBodyState();
}

class _TagFormBodyState extends State<_TagFormBody> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _colorHex;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.tag?.name ?? widget.initialName ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.tag?.description ?? '',
    );
    _colorHex =
        widget.tag?.colorHex ?? AppTagColors.hexOf(AppTagColors.choices.first);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? AppStrings.tagNameRequired : null;
    });
    if (name.isEmpty) {
      return;
    }

    final description = _descriptionController.text.trim();
    Navigator.of(context).pop(
      TagDraft(
        name: name,
        colorHex: _colorHex,
        description: description.isEmpty ? null : description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: AppStrings.tagNameLabel,
            hintText: AppStrings.tagNameHint,
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.tagColorLabel, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _ColorChoices(
          selected: _colorHex,
          onSelected: (hex) => setState(() => _colorHex = hex),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: AppStrings.tagDescriptionLabel,
            hintText: AppStrings.tagDescriptionHint,
            alignLabelWithHint: true,
          ),
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

class _ColorChoices extends StatelessWidget {
  const _ColorChoices({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final color in AppTagColors.choices)
          _ColorOption(
            color: color,
            isSelected: AppTagColors.hexOf(color) == selected,
            onTap: () => onSelected(AppTagColors.hexOf(color)),
          ),
      ],
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: AppStrings.tagPickColorLabel,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: isSelected
              ? Icon(
                  Icons.check_rounded,
                  size: AppSpacing.iconSize,
                  color: Theme.of(context).colorScheme.surface,
                )
              : null,
        ),
      ),
    );
  }
}
