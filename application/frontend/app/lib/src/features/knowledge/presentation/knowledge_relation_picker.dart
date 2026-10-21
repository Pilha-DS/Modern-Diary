import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../data/knowledge_repository.dart';
import '../domain/knowledge_models.dart';

/// Escolhe outro conhecimento para conectar. Pagina igual à lista principal.
Future<KnowledgeItem?> showKnowledgeRelationPicker(
  BuildContext context, {
  required KnowledgeDataSource dataSource,
  required int itemId,
  required Set<int> connectedIds,
}) {
  return showAppDialog<KnowledgeItem>(
    context,
    title: AppStrings.knowledgeRelationDialogTitle,
    closeLabel: AppStrings.close,
    maxWidth: 520,
    child: _RelationPickerBody(
      dataSource: dataSource,
      itemId: itemId,
      connectedIds: connectedIds,
    ),
  );
}

class _RelationPickerBody extends StatefulWidget {
  const _RelationPickerBody({
    required this.dataSource,
    required this.itemId,
    required this.connectedIds,
  });

  final KnowledgeDataSource dataSource;
  final int itemId;
  final Set<int> connectedIds;

  @override
  State<_RelationPickerBody> createState() => _RelationPickerBodyState();
}

class _RelationPickerBodyState extends State<_RelationPickerBody> {
  static const int _perPage = 10;

  List<KnowledgeItem> _items = const [];
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
        page: 1,
        perPage: _perPage,
      );
      setState(() {
        _items = page.items;
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } on ApiException catch (error) {
      setState(() => _error = error);
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
        page: _page + 1,
        perPage: _perPage,
      );
      setState(() {
        _items = [..._items, ...page.items];
        _page = page.page;
        _totalPages = page.totalPages;
      });
    } on ApiException catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  List<KnowledgeItem> get _candidates => _items
      .where(
        (item) =>
            item.id != widget.itemId && !widget.connectedIds.contains(item.id),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _items.isEmpty) {
      return const StatusView.loading(title: AppStrings.knowledgeLoading);
    }
    if (_error != null && _items.isEmpty) {
      return StatusView.error(
        title: AppStrings.knowledgeErrorTitle,
        message: _error!.message,
        actionLabel: AppStrings.retry,
        onAction: _loadFirstPage,
      );
    }

    final candidates = _candidates;
    if (candidates.isEmpty && !_hasMore) {
      return const StatusView.empty(
        icon: Icons.hub_outlined,
        title: AppStrings.knowledgeRelationDialogTitle,
        message: AppStrings.knowledgeNoCandidates,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in candidates)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              onTap: () => Navigator.of(context).pop(item),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    const Icon(Icons.hub_outlined, size: AppSpacing.iconSize),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        item.title,
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
          AppButton(
            label: AppStrings.knowledgeLoadMore,
            variant: AppButtonVariant.secondary,
            isLoading: _isLoadingMore,
            onPressed: _loadMore,
          ),
      ],
    );
  }
}
