import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../../tags/data/tags_repository.dart';
import '../../tags/domain/tag_models.dart';
import '../../tags/presentation/tag_filter_bar.dart';
import '../data/goals_repository.dart';
import '../domain/goal_models.dart';
import 'goal_card.dart';
import 'goal_detail_dialog.dart';
import 'goal_dialogs.dart';
import 'goals_controller.dart';

/// Lista de metas em três colunas, doze por página.
class GoalsSection extends StatefulWidget {
  const GoalsSection({
    super.key,
    required this.repository,
    required this.tagsRepository,
    required this.toat,
    this.navigation,
    this.focusGoalId,
    this.onFocusHandled,
  });

  final GoalsDataSource repository;
  final TagsDataSource tagsRepository;
  final ToatController toat;

  /// Liga tags e outras referências às áreas da home.
  final HomeNavigation? navigation;

  /// Meta que outra área pediu para abrir; o pedido é consumido ao abrir.
  final int? focusGoalId;
  final VoidCallback? onFocusHandled;

  @override
  State<GoalsSection> createState() => _GoalsSectionState();
}

class _GoalsSectionState extends State<GoalsSection> {
  late final GoalsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GoalsController(widget.repository)..loadFirstPage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
  }

  @override
  void didUpdateWidget(GoalsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusGoalId != oldWidget.focusGoalId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
    }
  }

  void _handleFocus() {
    final goalId = widget.focusGoalId;
    if (goalId == null || !mounted) {
      return;
    }
    widget.onFocusHandled?.call();
    _openGoalById(goalId);
  }

  Future<void> _openGoalById(int goalId) async {
    try {
      final goal = await widget.repository.fetchGoal(goalId);
      if (!mounted) {
        return;
      }
      await showGoalDetailDialog(
        context,
        goal: goal,
        onOpenTag: widget.navigation?.openTag,
      );
    } on ApiException catch (error) {
      if (mounted) {
        widget.toat.show(error.message, variant: ToatVariant.error);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createGoal() async {
    final draft = await showGoalFormDialog(
      context,
      title: AppStrings.newGoal,
      submitLabel: AppStrings.goalCreate,
      tagsSource: widget.tagsRepository,
    );
    if (draft == null || !mounted) {
      return;
    }

    final error = await _controller.createGoal(
      title: draft.title,
      description: draft.description,
      dueDate: draft.dueDate,
      steps: draft.steps,
      tagIds: [for (final tag in draft.tags) tag.id],
      sensitivity: draft.sensitivity,
    );
    _notify(error, AppStrings.goalCreated);
  }

  Future<void> _editGoal(Goal goal) async {
    final draft = await showGoalFormDialog(
      context,
      title: AppStrings.editGoal,
      submitLabel: AppStrings.goalSave,
      tagsSource: widget.tagsRepository,
      goal: goal,
    );
    if (draft == null || !mounted) {
      return;
    }

    final error = await _controller.updateGoal(
      goal.id,
      title: draft.title,
      description: draft.description,
      dueDate: draft.dueDate,
      tagIds: [for (final tag in draft.tags) tag.id],
      sensitivity: draft.sensitivity,
    );
    _notify(error, AppStrings.goalUpdated);
  }

  Future<void> _toggleCompleted(Goal goal) async {
    final error = await _controller.setCompleted(
      goal.id,
      completed: !goal.isCompleted,
    );
    _notify(
      error,
      goal.isCompleted ? AppStrings.goalReopened : AppStrings.goalCompleted,
    );
  }

  Future<void> _toggleArchived(Goal goal) async {
    if (!goal.isArchived) {
      final confirmed = await showAppConfirmDialog(
        context,
        title: AppStrings.goalArchiveTitle,
        message: AppStrings.goalArchiveMessage(goal.title),
        confirmLabel: AppStrings.goalArchiveAction,
        cancelLabel: AppStrings.cancel,
        variant: AppConfirmVariant.warning,
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    final error = await _controller.setArchived(
      goal.id,
      archived: !goal.isArchived,
    );
    _notify(
      error,
      goal.isArchived ? AppStrings.goalUnarchived : AppStrings.goalArchived,
    );
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.goalDeleteTitle,
      message: AppStrings.goalDeleteMessage(goal.title),
      confirmLabel: AppStrings.goalDeleteAction,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.danger,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final error = await _controller.deleteGoal(goal.id);
    _notify(error, AppStrings.goalDeleted);
  }

  Future<void> _addStep(Goal goal) async {
    final title = await showGoalStepDialog(context);
    if (title == null || !mounted) {
      return;
    }

    final error = await _controller.addStep(goal.id, title);
    _notify(error, AppStrings.goalStepCreated);
  }

  Future<void> _deleteStep(Goal goal, GoalStep step) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.goalStepDeleteTitle,
      message: AppStrings.goalStepDeleteMessage(step.title),
      confirmLabel: AppStrings.goalDeleteAction,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.warning,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final error = await _controller.deleteStep(goal.id, step.id);
    _notify(error, AppStrings.goalStepDeleted);
  }

  Future<void> _toggleStep(Goal goal, GoalStep step) async {
    final error = await _controller.toggleStep(goal.id, step);
    _notify(error, AppStrings.goalUpdated);
  }

  void _notify(ApiException? error, String successMessage) {
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? successMessage,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppStrings.goalsTitle, style: textTheme.titleMedium),
                if (!_controller.isLoading) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.goalsTotal(_controller.total),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            AppButton(
              label: AppStrings.newGoal,
              icon: Icons.add_rounded,
              isLoading: _controller.isCreating,
              onPressed: _controller.isCreating ? null : _createGoal,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TagFilterBar(
          dataSource: widget.tagsRepository,
          selectedTagId: _controller.tagId,
          onSelected: _controller.setTagFilter,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final filter in GoalFilter.values)
              AppButton(
                label: _filterLabel(filter),
                variant: _controller.filter == filter
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                onPressed: _controller.isLoading
                    ? null
                    : () => _controller.setFilter(filter),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_controller.isLoading)
          const StatusView.loading(title: AppStrings.goalsLoading)
        else if (_controller.error != null && _controller.goals.isEmpty)
          StatusView.error(
            title: AppStrings.goalsErrorTitle,
            message: _controller.error!.message,
            actionLabel: AppStrings.retry,
            onAction: _controller.loadFirstPage,
          )
        else if (_controller.goals.isEmpty)
          StatusView.empty(
            icon: Icons.flag_outlined,
            title: AppStrings.goalsEmptyTitle,
            message: _emptyMessage(_controller.filter),
          )
        else ...[
          if (_controller.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: InlineMessage(
                message: _controller.error!.message,
                variant: InlineMessageVariant.error,
              ),
            ),
          _GoalGrid(
            goals: _controller.goals,
            controller: _controller,
            onOpenTag: widget.navigation?.openTag,
            onEdit: _editGoal,
            onToggleCompleted: _toggleCompleted,
            onToggleArchived: _toggleArchived,
            onDelete: _deleteGoal,
            onAddStep: _addStep,
            onDeleteStep: _deleteStep,
            onToggleStep: _toggleStep,
          ),
          if (_controller.hasMore) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: AppButton(
                label: AppStrings.goalsLoadMore,
                variant: AppButtonVariant.secondary,
                isLoading: _controller.isLoadingMore,
                onPressed: _controller.loadMore,
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _filterLabel(GoalFilter filter) {
    final label = switch (filter) {
      GoalFilter.active => AppStrings.goalsFilterActive,
      GoalFilter.completed => AppStrings.goalsFilterCompleted,
      GoalFilter.archived => AppStrings.goalsFilterArchived,
    };
    return '$label (${_controller.countFor(filter)})';
  }

  String _emptyMessage(GoalFilter filter) {
    return switch (filter) {
      GoalFilter.active => AppStrings.goalsEmptyActiveMessage,
      GoalFilter.completed => AppStrings.goalsEmptyCompletedMessage,
      GoalFilter.archived => AppStrings.goalsEmptyArchivedMessage,
    };
  }
}

class _GoalGrid extends StatelessWidget {
  const _GoalGrid({
    required this.goals,
    required this.controller,
    required this.onOpenTag,
    required this.onEdit,
    required this.onToggleCompleted,
    required this.onToggleArchived,
    required this.onDelete,
    required this.onAddStep,
    required this.onDeleteStep,
    required this.onToggleStep,
  });

  final List<Goal> goals;
  final GoalsController controller;
  final ValueChanged<Tag>? onOpenTag;
  final ValueChanged<Goal> onEdit;
  final ValueChanged<Goal> onToggleCompleted;
  final ValueChanged<Goal> onToggleArchived;
  final ValueChanged<Goal> onDelete;
  final ValueChanged<Goal> onAddStep;
  final void Function(Goal goal, GoalStep step) onDeleteStep;
  final void Function(Goal goal, GoalStep step) onToggleStep;

  @override
  Widget build(BuildContext context) {
    return AppCardGrid(
      minCardWidth: 280,
      maxColumns: 3,
      children: [
        for (final goal in goals)
          GoalCard(
            goal: goal,
            isBusy: controller.isBusy(goal.id),
            onOpenTag: onOpenTag,
            onEdit: () => onEdit(goal),
            onToggleCompleted: () => onToggleCompleted(goal),
            onToggleArchived: () => onToggleArchived(goal),
            onDelete: () => onDelete(goal),
            onAddStep: () => onAddStep(goal),
            onToggleStep: (step) => onToggleStep(goal, step),
            onDeleteStep: (step) => onDeleteStep(goal, step),
          ),
      ],
    );
  }
}
