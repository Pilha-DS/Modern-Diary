import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../tags/domain/tag_models.dart';
import '../../tags/presentation/tag_chips.dart';
import '../domain/goal_models.dart';

/// Leitura de uma meta, aberta quando ela é referenciada em outra área.
Future<void> showGoalDetailDialog(
  BuildContext context, {
  required Goal goal,
  ValueChanged<Tag>? onOpenTag,
  DateTime? now,
}) {
  return showAppDialog<void>(
    context,
    title: goal.title,
    closeLabel: AppStrings.close,
    maxWidth: 560,
    child: _GoalDetailBody(goal: goal, onOpenTag: onOpenTag, now: now),
  );
}

class _GoalDetailBody extends StatelessWidget {
  const _GoalDetailBody({
    required this.goal,
    required this.onOpenTag,
    required this.now,
  });

  final Goal goal;
  final ValueChanged<Tag>? onOpenTag;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (goal.isCompleted || goal.isArchived)
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              if (goal.isCompleted)
                _Badge(
                  label: AppStrings.goalCompletedBadge,
                  background: colorScheme.primaryContainer,
                  foreground: colorScheme.primary,
                ),
              if (goal.isArchived)
                _Badge(
                  label: AppStrings.goalArchivedBadge,
                  background: colorScheme.surfaceContainerHighest,
                  foreground: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        if (goal.dueDate != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _DueDate(
            dueDate: goal.dueDate!,
            isOverdue: goal.isOverdue(now ?? DateTime.now()),
          ),
        ],
        if (goal.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          TagChips(
            tags: goal.tags,
            onTap: onOpenTag == null
                ? null
                : (tag) {
                    Navigator.of(context).maybePop();
                    onOpenTag!(tag);
                  },
          ),
        ],
        if (goal.hasDescription) ...[
          const SizedBox(height: AppSpacing.md),
          Text(AppStrings.goalDescriptionTitle, style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(goal.description!, style: textTheme.bodyMedium),
        ],
        const SizedBox(height: AppSpacing.md),
        AppProgressBar(
          value: goal.progress,
          label: AppStrings.goalProgress(goal.progressDone, goal.progressTotal),
          semanticLabel: AppStrings.goalProgressSemantics(
            goal.title,
            goal.progressDone,
            goal.progressTotal,
          ),
        ),
        if (goal.steps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.goalStepsTitle,
                  style: textTheme.titleSmall,
                ),
              ),
              Text(
                AppStrings.goalStepsCount(goal.steps.length),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          for (final step in goal.steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    step.isDone
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: AppSpacing.iconSize,
                    color: step.isDone
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      step.title,
                      style: textTheme.bodyMedium?.copyWith(
                        decoration: step.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: step.isDone
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DueDate extends StatelessWidget {
  const _DueDate({required this.dueDate, required this.isOverdue});

  final DateTime dueDate;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isOverdue
        ? AppSemanticColors.of(context).warning
        : colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(Icons.event_rounded, size: AppSpacing.iconSize, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            isOverdue
                ? AppStrings.goalOverdueDate(dueDate)
                : AppStrings.goalDueDate(dueDate),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
