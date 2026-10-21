import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/domain/goal_models.dart';

/// Escolhe uma meta ativa para ligar a um conhecimento.
Future<Goal?> showKnowledgeGoalPicker(
  BuildContext context, {
  required GoalsDataSource dataSource,
  required Set<int> linkedIds,
}) {
  return showAppDialog<Goal>(
    context,
    title: AppStrings.knowledgeGoalDialogTitle,
    closeLabel: AppStrings.close,
    maxWidth: 520,
    child: _GoalPickerBody(dataSource: dataSource, linkedIds: linkedIds),
  );
}

class _GoalPickerBody extends StatefulWidget {
  const _GoalPickerBody({required this.dataSource, required this.linkedIds});

  final GoalsDataSource dataSource;
  final Set<int> linkedIds;

  @override
  State<_GoalPickerBody> createState() => _GoalPickerBodyState();
}

class _GoalPickerBodyState extends State<_GoalPickerBody> {
  static const int _perPage = 10;

  List<Goal> _goals = const [];
  int _page = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  bool get _hasMore => _page < _totalPages;

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await widget.dataSource.fetchPage(
        filter: GoalFilter.active,
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _goals = page.goals;
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final page = await widget.dataSource.fetchPage(
        filter: GoalFilter.active,
        page: _page + 1,
        perPage: _perPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _goals = [..._goals, ...page.goals];
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  List<Goal> get _candidates =>
      _goals.where((goal) => !widget.linkedIds.contains(goal.id)).toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _goals.isEmpty) {
      return const StatusView.loading(title: AppStrings.goalsLoading);
    }
    if (_error != null && _goals.isEmpty) {
      return StatusView.error(
        title: AppStrings.goalsErrorTitle,
        message: _error!.message,
        actionLabel: AppStrings.retry,
        onAction: _loadFirstPage,
      );
    }

    final candidates = _candidates;
    if (candidates.isEmpty && !_hasMore) {
      return const StatusView.empty(
        icon: Icons.flag_outlined,
        title: AppStrings.knowledgeGoalDialogTitle,
        message: AppStrings.knowledgeNoGoalCandidates,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final goal in candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              onTap: () => Navigator.of(context).pop(goal),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: AppSpacing.iconSize),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        goal.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.goalsLoadMore,
              variant: AppButtonVariant.secondary,
              isLoading: _isLoadingMore,
              onPressed: _loadMore,
            ),
          ),
      ],
    );
  }
}
