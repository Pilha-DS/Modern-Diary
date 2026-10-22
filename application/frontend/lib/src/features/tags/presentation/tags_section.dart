import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../data/tags_repository.dart';
import '../domain/tag_models.dart';
import 'tag_chips.dart';
import 'tag_dialogs.dart';
import 'tag_usages_dialog.dart';
import 'tags_controller.dart';

/// Menu de tags: cadastro, edição e onde cada tag está sendo usada.
class TagsSection extends StatefulWidget {
  const TagsSection({
    super.key,
    required this.repository,
    required this.toat,
    this.navigation,
    this.focusTag,
    this.onFocusHandled,
  });

  final TagsDataSource repository;
  final ToatController toat;

  /// Leva cada uso da tag até a tela do registro.
  final HomeNavigation? navigation;

  /// Tag que outra área pediu para abrir; o pedido é consumido ao abrir.
  final Tag? focusTag;
  final VoidCallback? onFocusHandled;

  @override
  State<TagsSection> createState() => _TagsSectionState();
}

class _TagsSectionState extends State<TagsSection> {
  late final TagsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TagsController(widget.repository)..loadFirstPage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
  }

  @override
  void didUpdateWidget(TagsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTag?.id != oldWidget.focusTag?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
    }
  }

  void _handleFocus() {
    final tag = widget.focusTag;
    if (tag == null || !mounted) {
      return;
    }
    widget.onFocusHandled?.call();
    _openUsages(tag);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final draft = await showTagFormDialog(
      context,
      title: AppStrings.newTag,
      submitLabel: AppStrings.tagCreate,
    );
    if (draft == null || !mounted) {
      return;
    }
    final error = await _controller.createTag(draft);
    _notify(error, AppStrings.tagCreated);
  }

  Future<void> _edit(Tag tag) async {
    final draft = await showTagFormDialog(
      context,
      title: AppStrings.editTag,
      submitLabel: AppStrings.tagSave,
      tag: tag,
    );
    if (draft == null || !mounted) {
      return;
    }
    final error = await _controller.updateTag(tag.id, draft);
    _notify(error, AppStrings.tagUpdated);
  }

  Future<void> _delete(Tag tag) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.tagDeleteTitle,
      message: AppStrings.tagDeleteMessage(tag.name),
      confirmLabel: AppStrings.tagDeleteAction,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.danger,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final error = await _controller.deleteTag(tag.id);
    _notify(error, AppStrings.tagDeleted);
  }

  Future<void> _openUsages(Tag tag) {
    return showTagUsagesDialog(
      context,
      dataSource: widget.repository,
      tag: tag,
      onOpenUsage: widget.navigation == null ? null : _openUsage,
    );
  }

  void _openUsage(TagUsage usage) {
    final navigation = widget.navigation;
    if (navigation == null) {
      return;
    }
    switch (usage.targetType) {
      case TagTarget.knowledge:
        navigation.openKnowledgeItem(usage.targetId);
      case TagTarget.goal:
        navigation.openGoal(usage.targetId);
      case TagTarget.agendaDay:
        final day = usage.day;
        if (day != null) {
          navigation.openDay(day);
        }
    }
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
                Text(AppStrings.tagsTitle, style: textTheme.titleMedium),
                if (!_controller.isLoading) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.tagsTotal(_controller.total),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: AppStrings.refresh,
                  onPressed: _controller.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                AppButton(
                  label: AppStrings.newTag,
                  icon: Icons.add_rounded,
                  isLoading: _controller.isCreating,
                  onPressed: _controller.isCreating ? null : _create,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_controller.isLoading)
          const StatusView.loading(title: AppStrings.tagsLoading)
        else if (_controller.error != null && _controller.tags.isEmpty)
          StatusView.error(
            title: AppStrings.tagsErrorTitle,
            message: _controller.error!.message,
            actionLabel: AppStrings.retry,
            onAction: _controller.loadFirstPage,
          )
        else if (_controller.tags.isEmpty)
          const StatusView.empty(
            icon: Icons.sell_outlined,
            title: AppStrings.tagsEmptyTitle,
            message: AppStrings.tagsEmptyMessage,
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
          AppCardGrid(
            minCardWidth: 220,
            maxColumns: 4,
            children: [
              for (final tag in _controller.tags)
                _TagCard(
                  tag: tag,
                  isBusy: _controller.isBusy(tag.id),
                  onOpenUsages: () => _openUsages(tag),
                  onEdit: () => _edit(tag),
                  onDelete: () => _delete(tag),
                ),
            ],
          ),
          if (_controller.hasMore) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: AppButton(
                label: AppStrings.tagsLoadMore,
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
}

class _TagCard extends StatelessWidget {
  const _TagCard({
    required this.tag,
    required this.isBusy,
    required this.onOpenUsages,
    required this.onEdit,
    required this.onDelete,
  });

  /// Altura mínima do cartão: estreito e alto, com o rodapé preso embaixo.
  static const double _cardMinHeight = AppSpacing.xxl * 5;

  final Tag tag;
  final bool isBusy;
  final VoidCallback onOpenUsages;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _cardMinHeight),
      child: AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    onTap: isBusy ? null : onOpenUsages,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TagChip(
                            tag: tag,
                            onTap: isBusy ? null : onOpenUsages,
                          ),
                          if (tag.description != null &&
                              tag.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              tag.description!,
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
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: SizedBox.square(
                      dimension: AppSpacing.iconSize,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: AppStrings.tagEditAction,
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: AppSpacing.iconSize,
                    ),
                  ),
                  IconButton(
                    tooltip: AppStrings.tagDeleteAction,
                    onPressed: onDelete,
                    color: colorScheme.error,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: AppSpacing.iconSize,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  AppStrings.tagUsageTotal(tag.usageCount),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: isBusy ? null : onOpenUsages,
                  child: const Text(AppStrings.tagViewUsages),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
