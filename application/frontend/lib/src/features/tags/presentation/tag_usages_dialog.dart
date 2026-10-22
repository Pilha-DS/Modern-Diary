import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../data/tags_repository.dart';
import '../domain/tag_models.dart';

/// Mostra onde uma tag está sendo usada, com a mesma paginação do back.
///
/// `onOpenUsage` leva ao registro escolhido: o modal fecha e a home troca de
/// área. Sem ele, a lista é apenas informativa.
Future<void> showTagUsagesDialog(
  BuildContext context, {
  required TagsDataSource dataSource,
  required Tag tag,
  ValueChanged<TagUsage>? onOpenUsage,
}) {
  return showAppDialog<void>(
    context,
    title: AppStrings.tagUsageTitle(tag.name),
    closeLabel: AppStrings.close,
    maxWidth: 520,
    child: _TagUsagesBody(
      dataSource: dataSource,
      tag: tag,
      onOpenUsage: onOpenUsage,
    ),
  );
}

class _TagUsagesBody extends StatefulWidget {
  const _TagUsagesBody({
    required this.dataSource,
    required this.tag,
    this.onOpenUsage,
  });

  final TagsDataSource dataSource;
  final Tag tag;
  final ValueChanged<TagUsage>? onOpenUsage;

  @override
  State<_TagUsagesBody> createState() => _TagUsagesBodyState();
}

class _TagUsagesBodyState extends State<_TagUsagesBody> {
  static const int _perPage = 10;

  List<TagUsage> _usages = const [];
  int _page = 0;
  int _totalPages = 0;
  int _total = 0;
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
      final page = await widget.dataSource.fetchUsages(
        widget.tag.id,
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _usages = page.usages;
        _page = page.page;
        _total = page.total;
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
      final page = await widget.dataSource.fetchUsages(
        widget.tag.id,
        page: _page + 1,
        perPage: _perPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _usages = [..._usages, ...page.usages];
        _page = page.page;
        _total = page.total;
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading && _usages.isEmpty) {
      return const StatusView.loading(title: AppStrings.tagsLoading);
    }
    if (_error != null && _usages.isEmpty) {
      return StatusView.error(
        title: AppStrings.tagsErrorTitle,
        message: _error!.message,
        actionLabel: AppStrings.retry,
        onAction: _loadFirstPage,
      );
    }
    if (_usages.isEmpty) {
      return const StatusView.empty(
        icon: Icons.sell_outlined,
        title: AppStrings.tagUsageEmptyTitle,
        message: AppStrings.tagUsageEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.tagUsageTotal(_total),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final usage in _usages)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _UsageRow(
              usage: usage,
              onTap: widget.onOpenUsage == null
                  ? null
                  : () {
                      Navigator.of(context).maybePop();
                      widget.onOpenUsage!(usage);
                    },
            ),
          ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.tagUsageLoadMore,
              variant: AppButtonVariant.ghost,
              isLoading: _isLoadingMore,
              onPressed: _loadMore,
            ),
          ),
      ],
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.usage, this.onTap});

  final TagUsage usage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final (icon, typeLabel, title) = switch (usage.targetType) {
      TagTarget.knowledge => (
        Icons.hub_outlined,
        AppStrings.tagUsageKnowledge,
        usage.title ?? '',
      ),
      TagTarget.goal => (
        Icons.flag_outlined,
        AppStrings.tagUsageGoal,
        usage.title ?? '',
      ),
      TagTarget.agendaDay => (
        Icons.calendar_month_outlined,
        AppStrings.tagUsageDay,
        usage.day == null ? '' : AppStrings.fullDate(usage.day!),
      ),
    };

    final row = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSpacing.iconSize, color: colorScheme.onSurface),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
                Text(
                  typeLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: AppSpacing.iconSize,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }

    return Semantics(
      button: true,
      label: AppStrings.tagUsageOpenLabel(title.isEmpty ? typeLabel : title),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: row,
      ),
    );
  }
}
