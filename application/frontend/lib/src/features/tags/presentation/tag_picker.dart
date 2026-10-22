import 'dart:async';

import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../data/tags_repository.dart';
import '../domain/tag_models.dart';
import 'tag_chips.dart';
import 'tag_dialogs.dart';

/// Escolhe tags existentes ou cria uma nova no meio da seleção.
Future<List<Tag>?> showTagPicker(
  BuildContext context, {
  required TagsDataSource dataSource,
  List<Tag> selected = const [],
  String? initialQuery,
}) {
  return showAppDialog<List<Tag>>(
    context,
    title: AppStrings.tagPickerTitle,
    closeLabel: AppStrings.close,
    maxWidth: 480,
    child: _TagPickerBody(
      dataSource: dataSource,
      selected: selected,
      initialQuery: initialQuery,
    ),
  );
}

class _TagPickerBody extends StatefulWidget {
  const _TagPickerBody({
    required this.dataSource,
    required this.selected,
    this.initialQuery,
  });

  final TagsDataSource dataSource;
  final List<Tag> selected;
  final String? initialQuery;

  @override
  State<_TagPickerBody> createState() => _TagPickerBodyState();
}

class _TagPickerBodyState extends State<_TagPickerBody> {
  static const int _perPage = 10;
  static const Duration _debounce = Duration(milliseconds: 300);

  late final TextEditingController _queryController;
  late final Map<int, Tag> _selected;
  Timer? _searchTimer;

  List<Tag> _tags = const [];
  int _page = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isCreating = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _selected = {for (final tag in widget.selected) tag.id: tag};
    _queryController = TextEditingController(text: widget.initialQuery ?? '');
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  bool get _hasMore => _page < _totalPages;

  bool get _canCreate {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      return false;
    }
    return !_tags.any((tag) => tag.name.toLowerCase() == query.toLowerCase()) &&
        !_selected.values.any(
          (tag) => tag.name.toLowerCase() == query.toLowerCase(),
        );
  }

  void _onQueryChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_debounce, () {
      if (mounted) {
        _loadFirstPage();
      }
    });
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await widget.dataSource.fetchPage(
        page: 1,
        perPage: _perPage,
        query: _queryController.text,
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
        query: _queryController.text,
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

  void _toggle(Tag tag) {
    setState(() {
      if (_selected.containsKey(tag.id)) {
        _selected.remove(tag.id);
      } else {
        _selected[tag.id] = tag;
      }
    });
  }

  Future<void> _createFromQuery() async {
    final name = _queryController.text.trim();
    if (name.isEmpty || _isCreating) {
      return;
    }

    final draft = await showTagFormDialog(
      context,
      title: AppStrings.newTag,
      submitLabel: AppStrings.tagCreate,
      initialName: name,
    );
    if (draft == null || !mounted) {
      return;
    }

    setState(() {
      _isCreating = true;
      _error = null;
    });
    try {
      final created = await widget.dataSource.createTag(
        name: draft.name,
        colorHex: draft.colorHex,
        description: draft.description,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selected[created.id] = created;
        _tags = [created, ..._tags];
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selected.isNotEmpty) ...[
          TagChips(
            tags: _selected.values.toList(),
            onRemove: (tag) => _toggle(tag),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          controller: _queryController,
          autofocus: true,
          onChanged: _onQueryChanged,
          decoration: InputDecoration(
            labelText: AppStrings.tagPickerSearchHint,
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox.square(
                      dimension: AppSpacing.iconSize,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: InlineMessage(
              message: _error!.message,
              variant: InlineMessageVariant.error,
            ),
          ),
        if (_canCreate)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.tagPickerCreate(_queryController.text.trim()),
              icon: Icons.add_rounded,
              variant: AppButtonVariant.secondary,
              isLoading: _isCreating,
              onPressed: _isCreating ? null : _createFromQuery,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        if (_isLoading && _tags.isEmpty)
          const StatusView.loading(title: AppStrings.tagsLoading)
        else if (_tags.isEmpty)
          StatusView.empty(
            icon: Icons.sell_outlined,
            title: AppStrings.tagPickerEmpty,
            message: AppStrings.tagPickerSearchHint,
          )
        else
          for (final tag in _tags)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _TagOption(
                tag: tag,
                isSelected: _selected.containsKey(tag.id),
                onTap: () => _toggle(tag),
              ),
            ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.tagsLoadMore,
              variant: AppButtonVariant.ghost,
              isLoading: _isLoadingMore,
              onPressed: _loadMore,
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
              label: AppStrings.tagPickerDone,
              icon: Icons.check_rounded,
              onPressed: () =>
                  Navigator.of(context).pop(_selected.values.toList()),
            ),
          ],
        ),
        if (_selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              AppStrings.tagsTotal(_selected.length),
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _TagOption extends StatelessWidget {
  const _TagOption({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  final Tag tag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: isSelected,
      label: tag.name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: AppSpacing.md,
                height: AppSpacing.md,
                decoration: BoxDecoration(
                  color: tag.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                    if (tag.description != null &&
                        tag.description!.trim().isNotEmpty)
                      Text(
                        tag.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: AppSpacing.iconSize,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
