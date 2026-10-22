import 'dart:async';

import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../../tags/data/tags_repository.dart';
import '../../tags/presentation/tag_filter_bar.dart';
import '../data/search_repository.dart';
import '../domain/search_models.dart';
import 'search_controller.dart';

const List<String> _sensitivityLevels = [
  'publico',
  'basico',
  'moderado',
  'complexo',
  'sigiloso',
];

/// Abre a pesquisa universal: um campo para todas as áreas, com filtros.
Future<void> showSearchDialog(
  BuildContext context, {
  required SearchDataSource dataSource,
  required TagsDataSource tagsDataSource,
  required HomeNavigation navigation,
  String initialQuery = '',
}) {
  return showAppDialog<void>(
    context,
    title: AppStrings.searchTitle,
    closeLabel: AppStrings.searchClose,
    maxWidth: 720,
    child: _SearchPanel(
      dataSource: dataSource,
      tagsDataSource: tagsDataSource,
      navigation: navigation,
      initialQuery: initialQuery,
    ),
  );
}

String searchTypeLabel(SearchType type) {
  return AppStrings.auditEntityType(type.apiValue);
}

IconData searchTypeIcon(SearchType type) {
  return switch (type) {
    SearchType.knowledge => Icons.lightbulb_outline_rounded,
    SearchType.goal => Icons.flag_outlined,
    SearchType.note => Icons.sticky_note_2_outlined,
    SearchType.agendaNote => Icons.edit_calendar_outlined,
    SearchType.activity => Icons.checklist_rounded,
  };
}

class _SearchPanel extends StatefulWidget {
  const _SearchPanel({
    required this.dataSource,
    required this.tagsDataSource,
    required this.navigation,
    required this.initialQuery,
  });

  final SearchDataSource dataSource;
  final TagsDataSource tagsDataSource;
  final HomeNavigation navigation;
  final String initialQuery;

  @override
  State<_SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<_SearchPanel> {
  static const Duration _searchDebounce = Duration(milliseconds: 350);

  late final UniversalSearchController _controller;
  final TextEditingController _queryController = TextEditingController();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _controller = UniversalSearchController(widget.dataSource);
    if (widget.initialQuery.trim().isNotEmpty) {
      _queryController.text = widget.initialQuery;
      _controller.setQuery(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _queryController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () => _controller.setQuery(value));
  }

  void _submitQuery(String value) {
    _searchTimer?.cancel();
    _controller.setQuery(value);
  }

  void _clearQuery() {
    _searchTimer?.cancel();
    _queryController.clear();
    _controller.setQuery('');
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final from = _controller.from;
    final to = _controller.to;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: from == null || to == null
          ? null
          : DateTimeRange(start: from, end: to),
    );
    if (picked == null || !mounted) {
      return;
    }
    await _controller.setPeriod(from: picked.start, to: picked.end);
  }

  void _openResult(SearchResult result) {
    final ref = result.numericRef;
    // O modal fecha antes de trocar de área, como toda navegação do projeto.
    Navigator.of(context).maybePop();
    switch (result.type) {
      case SearchType.knowledge:
        if (ref != null) {
          widget.navigation.openKnowledgeItem(ref);
        }
      case SearchType.goal:
        if (ref != null) {
          widget.navigation.openGoal(ref);
        }
      case SearchType.note:
        if (ref != null) {
          widget.navigation.openNote(ref);
        }
      case SearchType.agendaNote:
      case SearchType.activity:
        final day = result.day;
        if (day != null) {
          widget.navigation.openDay(day);
        }
    }
  }

  String get _periodLabel {
    final from = _controller.from;
    final to = _controller.to;
    if (from == null && to == null) {
      return AppStrings.searchPeriodAny;
    }
    if (from != null && to != null) {
      return AppStrings.searchPeriodRange(
        AppStrings.shortDate(from),
        AppStrings.shortDate(to),
      );
    }
    return from != null
        ? AppStrings.searchPeriodFrom(AppStrings.shortDate(from))
        : AppStrings.searchPeriodUntil(AppStrings.shortDate(to!));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onQueryChanged,
              onSubmitted: _submitQuery,
              decoration: InputDecoration(
                hintText: AppStrings.searchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _queryController,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: AppStrings.searchClear,
                          onPressed: _clearQuery,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _typeFilter(),
            const SizedBox(height: AppSpacing.sm),
            _periodAndLevelFilter(),
            const SizedBox(height: AppSpacing.sm),
            TagFilterBar(
              dataSource: widget.tagsDataSource,
              selectedTagId: _controller.tagId,
              onSelected: _controller.setTag,
            ),
            const SizedBox(height: AppSpacing.md),
            _results(context),
          ],
        );
      },
    );
  }

  Widget _typeFilter() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppChip(
          label: AppStrings.searchAllTypes,
          isSelected: _controller.types.isEmpty,
          onTap: _controller.types.isEmpty ? null : _controller.clearTypes,
        ),
        for (final type in SearchType.values)
          AppChip(
            icon: searchTypeIcon(type),
            label: searchTypeLabel(type),
            isSelected: _controller.types.contains(type),
            onTap: () => _controller.toggleType(type),
          ),
      ],
    );
  }

  Widget _periodAndLevelFilter() {
    final hasPeriod = _controller.from != null || _controller.to != null;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppChip(
          icon: Icons.date_range_rounded,
          label: _periodLabel,
          isSelected: hasPeriod,
          onTap: _pickPeriod,
          onDeleted: hasPeriod ? () => _controller.setPeriod() : null,
          deleteLabel: AppStrings.searchPeriodClear,
        ),
        AppChip(
          label: AppStrings.searchAnyLevel,
          isSelected: _controller.sensitivity == null,
          onTap: _controller.sensitivity == null
              ? null
              : () => _controller.setSensitivity(null),
        ),
        for (final level in _sensitivityLevels)
          AppChip(
            label: AppStrings.sensitivityLabelOf(level),
            isSelected: _controller.sensitivity == level,
            onTap: () => _controller.setSensitivity(level),
          ),
      ],
    );
  }

  Widget _results(BuildContext context) {
    if (!_controller.hasQuery) {
      return const StatusView.empty(
        icon: Icons.search_rounded,
        title: AppStrings.searchStartTitle,
        message: AppStrings.searchStartMessage,
      );
    }
    if (_controller.isLoading) {
      return const StatusView.loading(title: AppStrings.searchLoading);
    }
    final error = _controller.error;
    if (error != null) {
      return StatusView.error(
        title: AppStrings.searchErrorTitle,
        message: error.message,
        actionLabel: AppStrings.searchRetry,
        onAction: _controller.retry,
      );
    }
    if (_controller.results.isEmpty) {
      return StatusView.empty(
        icon: Icons.search_off_rounded,
        title: AppStrings.searchEmptyTitle,
        message: AppStrings.searchEmptyMessage(_controller.query),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final result in _controller.results) ...[
          _SearchResultTile(result: result, onTap: () => _openResult(result)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                AppStrings.searchTotal(_controller.total),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (_controller.hasMore)
              AppButton(
                label: AppStrings.searchLoadMore,
                variant: AppButtonVariant.secondary,
                isLoading: _controller.isLoadingMore,
                onPressed: _controller.loadMore,
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final title = result.title?.trim();
    final snippet = result.snippet;
    final date = result.day ?? result.updatedAt;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppChip(
                      icon: searchTypeIcon(result.type),
                      label: searchTypeLabel(result.type),
                    ),
                    if (date != null)
                      AppChip(
                        icon: Icons.event_outlined,
                        label: AppStrings.shortDate(date),
                      ),
                    if (result.sensitivity != 'publico')
                      AppChip(
                        label: AppStrings.sensitivityLabelOf(
                          result.sensitivity,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  title != null && title.isNotEmpty
                      ? title
                      : AppStrings.noteUntitled,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall,
                ),
                if (snippet != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    snippet,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
