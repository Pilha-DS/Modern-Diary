import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../../tags/domain/tag_models.dart';
import '../../tags/presentation/tag_chips.dart';
import '../domain/goal_models.dart';

/// Cartão de uma meta: progresso, prazo, etapas e ações.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.isBusy,
    required this.onEdit,
    required this.onToggleCompleted,
    required this.onToggleArchived,
    required this.onDelete,
    required this.onToggleStep,
    required this.onAddStep,
    required this.onDeleteStep,
    this.onOpenTag,
    this.now,
  });

  final Goal goal;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onToggleCompleted;
  final VoidCallback onToggleArchived;
  final VoidCallback onDelete;
  final ValueChanged<GoalStep> onToggleStep;
  final VoidCallback onAddStep;
  final ValueChanged<GoalStep> onDeleteStep;

  /// Clique numa tag leva ao menu de tags; sem ele, a tag é só um marcador.
  final ValueChanged<Tag>? onOpenTag;

  /// Data usada para marcar atraso; vem de fora para o cartão ser determinístico.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final today = now ?? DateTime.now();
    final isArchived = goal.isArchived;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: textTheme.titleMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        SensitivityBadge(level: goal.sensitivity),
                        if (goal.isCompleted)
                          _Badge(
                            label: AppStrings.goalCompletedBadge,
                            background: colorScheme.primaryContainer,
                            foreground: colorScheme.primary,
                          ),
                        if (isArchived)
                          _Badge(
                            label: AppStrings.goalArchivedBadge,
                            background: colorScheme.surfaceContainerHighest,
                            foreground: colorScheme.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SizedBox.square(
                    dimension: AppSpacing.iconSize,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  tooltip: AppStrings.goalEditAction,
                  onPressed: isArchived ? null : onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: AppSpacing.iconSize,
                  ),
                ),
            ],
          ),
          if (goal.dueDate != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _DueDate(dueDate: goal.dueDate!, isOverdue: goal.isOverdue(today)),
          ],
          if (goal.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            TagChips(tags: goal.tags, onTap: onOpenTag),
          ],
          if (goal.hasDescription) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              goal.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(
            value: goal.progress,
            label: AppStrings.goalProgress(
              goal.progressDone,
              goal.progressTotal,
            ),
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
              _StepRow(
                step: step,
                enabled: !isBusy && !isArchived,
                onToggle: () => onToggleStep(step),
                onDelete: () => onDeleteStep(step),
              ),
          ],
          if (!isArchived) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: AppStrings.goalAddStep,
                icon: Icons.add_rounded,
                variant: AppButtonVariant.ghost,
                onPressed: isBusy ? null : onAddStep,
              ),
            ),
          ],
          // A grade iguala a altura dos cartões da linha: o espaço extra fica
          // antes das ações, que seguem no rodapé de todos.
          const Spacer(),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (!isArchived)
                IconButton(
                  tooltip: goal.isCompleted
                      ? AppStrings.goalReopenAction
                      : AppStrings.goalCompleteAction,
                  onPressed: isBusy ? null : onToggleCompleted,
                  color: colorScheme.primary,
                  icon: Icon(
                    goal.isCompleted
                        ? Icons.undo_rounded
                        : Icons.check_circle_outline_rounded,
                    size: AppSpacing.iconSize,
                  ),
                ),
              IconButton(
                tooltip: isArchived
                    ? AppStrings.goalUnarchiveAction
                    : AppStrings.goalArchiveAction,
                onPressed: isBusy ? null : onToggleArchived,
                icon: Icon(
                  isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  size: AppSpacing.iconSize,
                ),
              ),
              IconButton(
                tooltip: AppStrings.goalDeleteAction,
                onPressed: isBusy ? null : onDelete,
                color: colorScheme.error,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: AppSpacing.iconSize,
                ),
              ),
            ],
          ),
        ],
      ),
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

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.enabled,
    required this.onToggle,
    required this.onDelete,
  });

  final GoalStep step;
  final bool enabled;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        IconButton(
          tooltip: step.isDone
              ? AppStrings.goalStepPendingLabel(step.title)
              : AppStrings.goalStepDoneLabel(step.title),
          onPressed: enabled ? onToggle : null,
          color: step.isDone
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
          icon: Icon(
            step.isDone
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: AppSpacing.iconSize,
          ),
        ),
        Expanded(
          child: Text(
            step.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              decoration: step.isDone ? TextDecoration.lineThrough : null,
              color: step.isDone
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          tooltip: AppStrings.goalStepDeleteAction,
          onPressed: enabled ? onDelete : null,
          color: colorScheme.onSurfaceVariant,
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: AppSpacing.iconSize,
          ),
        ),
      ],
    );
  }
}
