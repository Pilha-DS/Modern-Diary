import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../data/tags_repository.dart';
import '../domain/tag_models.dart';

/// Filtro por tag reutilizável: carrega as tags paginadas e devolve a escolha.
class TagFilterBar extends StatefulWidget {
  const TagFilterBar({
    super.key,
    required this.dataSource,
    required this.selectedTagId,
    required this.onSelected,
  });

  final TagsDataSource dataSource;
  final int? selectedTagId;
  final ValueChanged<int?> onSelected;

  @override
  State<TagFilterBar> createState() => _TagFilterBarState();
}

class _TagFilterBarState extends State<TagFilterBar> {
  static const int _perPage = 20;

  List<Tag> _tags = const [];
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
      if (!mounted) {
        return;
      }
      setState(() {
        _tags = page.tags;
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
        page: _page + 1,
        perPage: _perPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _tags = [..._tags, ...page.tags];
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

  @override
  Widget build(BuildContext context) {
    if (_error != null && _tags.isEmpty) {
      return InlineMessage(
        message: _error!.message,
        variant: InlineMessageVariant.error,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          AppChip(
            label: AppStrings.tagFilterAll,
            isSelected: widget.selectedTagId == null,
            onTap: () => widget.onSelected(null),
          ),
          for (final tag in _tags) ...[
            const SizedBox(width: AppSpacing.sm),
            AppChip(
              label: tag.name,
              accent: AppTagColors.parse(tag.colorHex),
              isSelected: widget.selectedTagId == tag.id,
              onTap: () => widget.onSelected(tag.id),
            ),
          ],
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SizedBox.square(
                dimension: AppSpacing.iconSize,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_hasMore) ...[
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: AppStrings.tagsLoadMore,
              variant: AppButtonVariant.ghost,
              isLoading: _isLoadingMore,
              onPressed: _loadMore,
            ),
          ],
        ],
      ),
    );
  }
}
