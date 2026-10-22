import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../../goals/data/goals_repository.dart';
import '../../home/presentation/home_navigation.dart';
import '../../tags/data/tags_repository.dart';
import '../../tags/presentation/tag_chips.dart';
import '../../tags/presentation/tag_filter_bar.dart';
import '../data/knowledge_repository.dart';
import '../domain/knowledge_models.dart';
import 'knowledge_card.dart';
import 'knowledge_collection_dialog.dart';
import 'knowledge_controller.dart';
import 'knowledge_detail_dialog.dart';
import 'knowledge_dialogs.dart';
import 'knowledge_goal_picker.dart';
import 'knowledge_graph_view.dart';
import 'knowledge_link_dialog.dart';
import 'knowledge_relation_picker.dart';

/// Base de conhecimentos: lista por padrão, com visão em grafo da rede.
class KnowledgeSection extends StatefulWidget {
  const KnowledgeSection({
    super.key,
    required this.repository,
    required this.tagsRepository,
    required this.goalsRepository,
    required this.toat,
    this.navigation,
    this.focusItemId,
    this.onFocusHandled,
  });

  final KnowledgeDataSource repository;
  final TagsDataSource tagsRepository;
  final GoalsDataSource goalsRepository;
  final ToatController toat;

  /// Liga tags, metas e conhecimentos às áreas da home.
  final HomeNavigation? navigation;

  /// Conhecimento que outra área pediu para abrir; o pedido é consumido.
  final int? focusItemId;
  final VoidCallback? onFocusHandled;

  @override
  State<KnowledgeSection> createState() => _KnowledgeSectionState();
}

class _KnowledgeSectionState extends State<KnowledgeSection> {
  late final KnowledgeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = KnowledgeController(widget.repository)..loadFirstPage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
  }

  @override
  void didUpdateWidget(KnowledgeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusItemId != oldWidget.focusItemId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
    }
  }

  void _handleFocus() {
    final itemId = widget.focusItemId;
    if (itemId == null || !mounted) {
      return;
    }
    widget.onFocusHandled?.call();
    _openRelated(itemId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final draft = await showKnowledgeFormDialog(
      context,
      title: AppStrings.newKnowledge,
      submitLabel: AppStrings.knowledgeCreate,
      tagsSource: widget.tagsRepository,
    );
    if (draft == null || !mounted) {
      return;
    }

    final error = await _controller.createItem(
      title: draft.title,
      content: draft.content,
      links: draft.links,
      files: draft.files,
      tagIds: [for (final tag in draft.tags) tag.id],
      sensitivity: draft.sensitivity,
    );
    _notify(error, AppStrings.knowledgeCreated);
  }

  Future<void> _edit(KnowledgeItem item) async {
    final draft = await showKnowledgeFormDialog(
      context,
      title: AppStrings.editKnowledge,
      submitLabel: AppStrings.knowledgeSave,
      tagsSource: widget.tagsRepository,
      item: item,
    );
    if (draft == null || !mounted) {
      return;
    }

    final error = await _controller.updateItem(
      item.id,
      title: draft.title,
      content: draft.content,
      links: draft.links,
      files: draft.files,
      tagIds: [for (final tag in draft.tags) tag.id],
      sensitivity: draft.sensitivity,
    );
    _notify(error, AppStrings.knowledgeUpdated);
  }

  Future<void> _delete(KnowledgeItem item) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.knowledgeDeleteTitle,
      message: AppStrings.knowledgeDeleteMessage(item.title),
      confirmLabel: AppStrings.knowledgeDeleteAction,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.danger,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final error = await _controller.deleteItem(item.id);
    _notify(error, AppStrings.knowledgeDeleted);
  }

  Future<void> _openGoals(KnowledgeItem item) {
    return showKnowledgeCollectionDialog<KnowledgeGoalReference>(
      context: context,
      title: AppStrings.knowledgeGoalsTitle,
      entries: item.goals,
      icon: Icons.flag_outlined,
      emptyMessage: AppStrings.knowledgeNoLinkedGoals,
      addLabel: AppStrings.knowledgeLinkGoal,
      labelOf: (goal) => goal.title,
      removeLabelOf: (goal) => AppStrings.knowledgeRemoveGoalLabel(goal.title),
      onAdd: (current) => _addGoal(item, current),
      onRemove: (goal, _) => _removeGoal(item, goal),
      onEntryTap: widget.navigation == null
          ? null
          : (goal) => widget.navigation!.openGoal(goal.id),
    );
  }

  Future<KnowledgeGoalReference?> _addGoal(
    KnowledgeItem item,
    List<KnowledgeGoalReference> current,
  ) async {
    final goal = await showKnowledgeGoalPicker(
      context,
      dataSource: widget.goalsRepository,
      linkedIds: {for (final linked in current) linked.id},
    );
    if (goal == null || !mounted) {
      return null;
    }

    final error = await _controller.addGoal(item.id, goal.id);
    _notify(error, AppStrings.knowledgeGoalLinked);
    return error == null
        ? KnowledgeGoalReference(id: goal.id, title: goal.title)
        : null;
  }

  Future<bool> _removeGoal(
    KnowledgeItem item,
    KnowledgeGoalReference goal,
  ) async {
    final error = await _controller.removeGoal(item.id, goal.id);
    _notify(error, AppStrings.knowledgeGoalUnlinked);
    return error == null;
  }

  Future<void> _openConnections(KnowledgeItem item) {
    return showKnowledgeCollectionDialog<KnowledgeReference>(
      context: context,
      title: AppStrings.knowledgeConnectionsCell,
      entries: item.relations,
      icon: Icons.hub_outlined,
      emptyMessage: AppStrings.knowledgeNoRelations,
      addLabel: AppStrings.knowledgeConnect,
      labelOf: (relation) => relation.title,
      removeLabelOf: (relation) =>
          AppStrings.knowledgeRemoveRelationLabel(relation.title),
      onAdd: (current) => _addConnection(item, current),
      onRemove: (relation, _) => _removeRelation(item, relation),
      onEntryTap: (relation) => _openRelated(relation.id),
    );
  }

  Future<KnowledgeReference?> _addConnection(
    KnowledgeItem item,
    List<KnowledgeReference> current,
  ) async {
    final target = await showKnowledgeRelationPicker(
      context,
      dataSource: widget.repository,
      itemId: item.id,
      connectedIds: {for (final relation in current) relation.id},
    );
    if (target == null || !mounted) {
      return null;
    }

    final error = await _controller.addRelation(item.id, target.id);
    _notify(error, AppStrings.knowledgeRelationCreated);
    return error == null
        ? KnowledgeReference(id: target.id, title: target.title)
        : null;
  }

  Future<bool> _removeRelation(
    KnowledgeItem item,
    KnowledgeReference relation,
  ) async {
    final error = await _controller.removeRelation(item.id, relation.id);
    _notify(error, AppStrings.knowledgeRelationRemoved);
    return error == null;
  }

  /// Conexão criada arrastando um nó sobre outro, no grafo.
  Future<void> _connectFromGraph(
    KnowledgeNodeData source,
    KnowledgeNodeData target,
  ) async {
    final error = await _controller.addRelation(source.id, target.id);
    _notify(error, AppStrings.knowledgeGraphConnected(target.title));
  }

  Future<void> _openLinks(KnowledgeItem item) {
    return showKnowledgeCollectionDialog<KnowledgeExternalLink>(
      context: context,
      title: AppStrings.knowledgeLinksCell,
      entries: item.links,
      icon: Icons.link_rounded,
      emptyMessage: AppStrings.knowledgeNoLinks,
      addLabel: AppStrings.knowledgeAddLink,
      labelOf: (link) => link.displayLabel,
      removeLabelOf: (link) =>
          AppStrings.knowledgeRemoveLinkLabel(link.displayLabel),
      onAdd: (current) => _addLink(item, current),
      onRemove: (link, current) {
        final remaining = [
          for (final kept in current)
            if (!identical(kept, link)) kept,
        ];
        return _saveLinks(item, remaining);
      },
      onEntryTap: _openLink,
    );
  }

  Future<KnowledgeExternalLink?> _addLink(
    KnowledgeItem item,
    List<KnowledgeExternalLink> current,
  ) async {
    final link = await showKnowledgeLinkDialog(context);
    if (link == null || !mounted) {
      return null;
    }
    final saved = await _saveLinks(item, [...current, link]);
    return saved ? link : null;
  }

  Future<bool> _saveLinks(
    KnowledgeItem item,
    List<KnowledgeExternalLink> links,
  ) async {
    final error = await _controller.updateLinks(item.id, links);
    _notify(error, AppStrings.knowledgeLinksUpdated);
    return error == null;
  }

  Future<void> _openTags(KnowledgeItem item) {
    return showAppDialog<void>(
      context,
      title: AppStrings.knowledgeTagsCell,
      closeLabel: AppStrings.close,
      maxWidth: 480,
      child: item.tags.isEmpty
          ? const StatusView.empty(
              icon: Icons.sell_outlined,
              title: AppStrings.knowledgeTagsCell,
              message: AppStrings.knowledgeNoTags,
            )
          : TagChips(
              tags: item.tags,
              onTap: (tag) {
                Navigator.of(context).maybePop();
                widget.navigation?.openTag(tag);
              },
            ),
    );
  }

  Future<void> _removeAttachment(
    KnowledgeItem item,
    KnowledgeAttachment attachment,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.knowledgeDeleteAttachmentTitle,
      message: AppStrings.knowledgeDeleteAttachmentMessage(attachment.filename),
      confirmLabel: AppStrings.delete,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.warning,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final error = await _controller.deleteAttachment(item.id, attachment.id);
    _notify(error, AppStrings.knowledgeAttachmentRemoved);
  }

  Future<void> _openLink(KnowledgeExternalLink link) =>
      _openUri(Uri.tryParse(link.url));

  Future<void> _openAttachment(KnowledgeAttachment attachment) =>
      _openUri(_controller.attachmentDownloadUri(attachment));

  Future<void> _openUri(Uri? uri) async {
    if (uri == null) {
      widget.toat.show(
        AppStrings.knowledgeAttachmentFailed,
        variant: ToatVariant.error,
      );
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        widget.toat.show(
          AppStrings.knowledgeAttachmentFailed,
          variant: ToatVariant.error,
        );
      }
    } catch (_) {
      if (mounted) {
        widget.toat.show(
          AppStrings.knowledgeAttachmentFailed,
          variant: ToatVariant.error,
        );
      }
    }
  }

  Future<void> _openRelated(int itemId) async {
    try {
      final item = await widget.repository.fetchItem(itemId);
      if (!mounted) {
        return;
      }
      await _openDetail(item);
    } on ApiException catch (error) {
      if (mounted) {
        widget.toat.show(error.message, variant: ToatVariant.error);
      }
    }
  }

  Future<void> _openDetail(KnowledgeItem item) {
    return showKnowledgeDetailDialog(
      context,
      item: item,
      onContentChanged: (content) => _saveContent(item, content),
      onAddObservation: (text) => _addObservation(item, text),
      onRemoveObservation: (observation) =>
          _removeObservation(item, observation),
      onOpenAttachment: _openAttachment,
      onRemoveAttachment: (attachment) => _removeAttachment(item, attachment),
    );
  }

  Future<(KnowledgeObservation?, ApiException?)> _addObservation(
    KnowledgeItem item,
    String text,
  ) async {
    final (observation, error) = await _controller.addObservation(
      item.id,
      text,
    );
    _notify(error, AppStrings.knowledgeObservationAdded);
    return (observation, error);
  }

  Future<ApiException?> _removeObservation(
    KnowledgeItem item,
    KnowledgeObservation observation,
  ) async {
    final error = await _controller.deleteObservation(item.id, observation.id);
    _notify(error, AppStrings.knowledgeObservationRemoved);
    return error;
  }

  Future<ApiException?> _saveContent(KnowledgeItem item, String content) async {
    final error = await _controller.updateContent(
      item.id,
      content.isEmpty ? null : content,
    );
    _notify(error, AppStrings.knowledgeUpdated);
    return error;
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
    final isGraph = _controller.view == KnowledgeView.graph;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(AppStrings.knowledgeTitle, style: textTheme.titleMedium),
                if (!_controller.isLoading)
                  Text(
                    AppStrings.knowledgeTotal(_controller.total),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
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
                  label: AppStrings.newKnowledge,
                  icon: Icons.add_rounded,
                  isLoading: _controller.isCreating,
                  onPressed: _controller.isCreating ? null : _create,
                ),
              ],
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
            AppButton(
              label: AppStrings.knowledgeViewList,
              icon: Icons.view_list_outlined,
              variant: isGraph
                  ? AppButtonVariant.secondary
                  : AppButtonVariant.primary,
              onPressed: () => _controller.setView(KnowledgeView.list),
            ),
            AppButton(
              label: AppStrings.knowledgeViewGraph,
              icon: Icons.hub_outlined,
              variant: isGraph
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              onPressed: () => _controller.setView(KnowledgeView.graph),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isGraph) _buildGraph(context) else _buildList(context),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (_controller.isLoading) {
      return const StatusView.loading(title: AppStrings.knowledgeLoading);
    }
    if (_controller.error != null && _controller.items.isEmpty) {
      return StatusView.error(
        title: AppStrings.knowledgeErrorTitle,
        message: _controller.error!.message,
        actionLabel: AppStrings.retry,
        onAction: _controller.loadFirstPage,
      );
    }
    if (_controller.items.isEmpty) {
      return const StatusView.empty(
        icon: Icons.hub_outlined,
        title: AppStrings.knowledgeEmptyTitle,
        message: AppStrings.knowledgeEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_controller.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: InlineMessage(
              message: _controller.error!.message,
              variant: InlineMessageVariant.error,
            ),
          ),
        AppCardGrid(
          minCardWidth: 200,
          maxColumns: 4,
          children: [
            for (final item in _controller.items)
              KnowledgeCard(
                item: item,
                isBusy: _controller.isBusy(item.id),
                onOpen: () => _openDetail(item),
                onEdit: () => _edit(item),
                onDelete: () => _delete(item),
                onOpenGoals: () => _openGoals(item),
                onOpenLinks: () => _openLinks(item),
                onOpenConnections: () => _openConnections(item),
                onOpenTag: widget.navigation?.openTag,
                onShowAllTags: item.tags.isEmpty ? null : () => _openTags(item),
              ),
          ],
        ),
        if (_controller.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: AppButton(
                label: AppStrings.knowledgeLoadMore,
                variant: AppButtonVariant.secondary,
                isLoading: _controller.isLoadingMore,
                onPressed: _controller.loadMore,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGraph(BuildContext context) {
    final graph = _controller.graph;

    if (_controller.isLoadingGraph && graph == null) {
      return const StatusView.loading(title: AppStrings.knowledgeGraphLoading);
    }
    if (_controller.graphError != null && graph == null) {
      return StatusView.error(
        title: AppStrings.knowledgeErrorTitle,
        message: _controller.graphError!.message,
        actionLabel: AppStrings.retry,
        onAction: _controller.loadGraph,
      );
    }
    if (graph == null || graph.nodes.isEmpty) {
      return const StatusView.empty(
        icon: Icons.hub_outlined,
        title: AppStrings.knowledgeGraphEmptyTitle,
        message: AppStrings.knowledgeGraphEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.6).clamp(320, 560),
          child: AppSurface(
            child: KnowledgeGraphView(
              graph: graph,
              onNodeTap: (node) => _openRelated(node.id),
              onConnect: _connectFromGraph,
            ),
          ),
        ),
        if (graph.truncated)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              AppStrings.knowledgeGraphTruncated(
                graph.nodes.length,
                graph.total,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
