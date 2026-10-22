import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart' hide SensitivityBadge, SensitivitySelector;

import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../../tags/data/tags_repository.dart';
import '../../tags/domain/tag_models.dart';
import '../../tags/presentation/tag_chips.dart';
import '../../tags/presentation/tag_picker.dart';
import '../domain/goal_models.dart';

/// Dados coletados no formulário de meta.
class GoalDraft {
  const GoalDraft({
    required this.title,
    this.description,
    this.dueDate,
    this.steps = const [],
    this.tags = const [],
    this.sensitivity = SensitivityLevel.publico,
  });

  final String title;
  final String? description;
  final DateTime? dueDate;
  final List<String> steps;
  final List<Tag> tags;
  final SensitivityLevel sensitivity;
}

Future<GoalDraft?> showGoalFormDialog(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required TagsDataSource tagsSource,
  Goal? goal,
}) {
  return showAppDialog<GoalDraft>(
    context,
    title: title,
    closeLabel: AppStrings.close,
    maxWidth: 520,
    child: _GoalFormBody(
      submitLabel: submitLabel,
      goal: goal,
      tagsSource: tagsSource,
    ),
  );
}

Future<String?> showGoalStepDialog(BuildContext context) {
  return showAppDialog<String>(
    context,
    title: AppStrings.goalStepDialogTitle,
    closeLabel: AppStrings.close,
    maxWidth: 420,
    child: const _GoalStepBody(),
  );
}

class _GoalFormBody extends StatefulWidget {
  const _GoalFormBody({
    required this.submitLabel,
    required this.tagsSource,
    this.goal,
  });

  final String submitLabel;
  final TagsDataSource tagsSource;
  final Goal? goal;

  @override
  State<_GoalFormBody> createState() => _GoalFormBodyState();
}

class _GoalFormBodyState extends State<_GoalFormBody> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final List<TextEditingController> _stepControllers = [];
  late List<Tag> _tags;
  DateTime? _dueDate;
  late SensitivityLevel _sensitivity;
  String? _titleError;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.goal?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.goal?.description ?? '',
    );
    _dueDate = widget.goal?.dueDate;
    _sensitivity = widget.goal?.sensitivity ?? SensitivityLevel.publico;
    _tags = [...?widget.goal?.tags];
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
    _descriptionController.dispose();
    for (final controller in _stepControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addStepField() {
    setState(() => _stepControllers.add(TextEditingController()));
  }

  void _removeStepField(int index) {
    final controller = _stepControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _dueDate = DateTime(picked.year, picked.month, picked.day));
  }

  void _submit() {
    final title = _titleController.text.trim();
    setState(() {
      _titleError = title.isEmpty ? AppStrings.goalTitleRequired : null;
    });
    if (title.isEmpty) {
      return;
    }

    final description = _descriptionController.text.trim();
    final steps = _isEditing
        ? const <String>[]
        : [
            for (final controller in _stepControllers)
              if (controller.text.trim().isNotEmpty) controller.text.trim(),
          ];

    Navigator.of(context).pop(
      GoalDraft(
        title: title,
        description: description.isEmpty ? null : description,
        dueDate: _dueDate,
        steps: steps,
        tags: _tags,
        sensitivity: _sensitivity,
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
          controller: _titleController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: AppStrings.goalTitleLabel,
            hintText: AppStrings.goalTitleHint,
            errorText: _titleError,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _descriptionController,
          minLines: 2,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: AppStrings.goalDescriptionLabel,
            hintText: AppStrings.goalDescriptionHint,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _pickDueDate,
                icon: const Icon(
                  Icons.event_rounded,
                  size: AppSpacing.iconSize,
                ),
                label: Text(
                  _dueDate == null
                      ? AppStrings.goalDueDatePick
                      : AppStrings.goalDueDate(_dueDate!),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_dueDate != null)
              IconButton(
                tooltip: AppStrings.goalDueDateClear,
                onPressed: () => setState(() => _dueDate = null),
                icon: const Icon(
                  Icons.close_rounded,
                  size: AppSpacing.iconSize,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SensitivitySelector(
          label: AppStrings.sensitivityGoalLabel,
          selected: _sensitivity,
          onChanged: (level) => setState(() => _sensitivity = level),
        ),
        const SizedBox(height: AppSpacing.sm),
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
        if (!_isEditing) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.goalStepsLabel,
                  style: textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: AppStrings.goalAddStep,
                onPressed: _addStepField,
                icon: const Icon(Icons.add_rounded, size: AppSpacing.iconSize),
              ),
            ],
          ),
          for (var index = 0; index < _stepControllers.length; index++) ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _stepControllers[index],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: AppStrings.goalStepLabel,
                      hintText: AppStrings.goalStepHint,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.goalStepDeleteAction,
                  onPressed: () => _removeStepField(index),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: AppSpacing.iconSize,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
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

class _GoalStepBody extends StatefulWidget {
  const _GoalStepBody();

  @override
  State<_GoalStepBody> createState() => _GoalStepBodyState();
}

class _GoalStepBodyState extends State<_GoalStepBody> {
  final TextEditingController _titleController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    setState(() {
      _error = title.isEmpty ? AppStrings.goalStepTitleRequired : null;
    });
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: AppStrings.goalStepLabel,
            hintText: AppStrings.goalStepHint,
            errorText: _error,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
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
              label: AppStrings.goalStepCreate,
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
