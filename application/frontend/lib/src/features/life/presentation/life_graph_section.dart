import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../data/life_repository.dart';
import '../domain/life_models.dart';
import 'life_graph_controller.dart';
import 'life_graph_view.dart';
import 'life_links_dialog.dart';
import 'life_node_preview.dart';

/// Live graph: tudo o que o usuário registrou, ligado por relação ou à mão.
class LifeGraphSection extends StatefulWidget {
  const LifeGraphSection({
    super.key,
    required this.repository,
    required this.toat,
    this.navigation,
  });

  final LifeDataSource repository;
  final ToatController toat;
  final HomeNavigation? navigation;

  @override
  State<LifeGraphSection> createState() => _LifeGraphSectionState();
}

class _LifeGraphSectionState extends State<LifeGraphSection> {
  late final LifeGraphController _controller;

  @override
  void initState() {
    super.initState();
    _controller = LifeGraphController(widget.repository)..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _connect(LifeGraphNode source, LifeGraphNode target) async {
    if (_controller.isBusy) {
      return;
    }
    final error = await _controller.connect(source, target);
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ??
          AppStrings.liveGraphConnected(
            lifeNodeLabel(source),
            lifeNodeLabel(target),
          ),
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  Future<void> _openLinks() async {
    final edge = await showLifeLinksDialog(context, graph: _controller.graph);
    if (edge == null || !mounted) {
      return;
    }
    final graph = _controller.graph;
    final source = graph.nodeById(edge.source);
    final target = graph.nodeById(edge.target);
    if (source == null || target == null) {
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.liveGraphRemoveLinkTitle,
      message: AppStrings.liveGraphRemoveLinkMessage(
        lifeNodeLabel(source),
        lifeNodeLabel(target),
      ),
      confirmLabel: AppStrings.liveGraphRemoveLinkAction,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.warning,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final error = await _controller.disconnect(source, target);
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? AppStrings.liveGraphLinkRemoved,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  void _openNode(LifeGraphNode node) {
    final navigation = widget.navigation;
    if (navigation == null) {
      return;
    }
    switch (node.type) {
      case LifeEntityType.knowledge:
        final id = node.numericRef;
        if (id != null) {
          navigation.openKnowledgeItem(id);
        }
      case LifeEntityType.goal:
        final id = node.numericRef;
        if (id != null) {
          navigation.openGoal(id);
        }
      case LifeEntityType.note:
        final id = node.numericRef;
        if (id != null) {
          navigation.openNote(id);
        }
      case LifeEntityType.day:
        if (node.day != null) {
          navigation.openDay(node.day!);
        }
      case LifeEntityType.activity:
        // A atividade mora no painel do dia.
        if (node.day != null) {
          navigation.openDay(node.day!);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final graph = _controller.graph;
        final manualLinks = graph.edges.where((edge) => edge.isCustom).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.liveGraphTitle, style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.liveGraphSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppButton(
                  label: AppStrings.liveGraphLinksButton,
                  icon: Icons.link_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: _controller.isBusy || manualLinks == 0
                      ? null
                      : _openLinks,
                ),
                IconButton(
                  tooltip: AppStrings.liveGraphRefresh,
                  onPressed: _controller.isLoading
                      ? null
                      : () => _controller.load(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                Text(
                  AppStrings.liveGraphLinksCount(manualLinks),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _filter(context),
            const SizedBox(height: AppSpacing.md),
            _content(context),
            if (!_controller.isLoading && _controller.error == null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppStrings.liveGraphTotal(graph.nodes.length),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _filter(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        AppChip(
          label: AppStrings.liveGraphAllTypes,
          isSelected: _controller.types.isEmpty,
          onTap: _controller.types.isEmpty ? null : _controller.clearTypes,
        ),
        for (final type in LifeEntityType.values)
          AppChip(
            label: lifeEntityTypeLabel(type),
            isSelected: _controller.types.contains(type),
            onTap: () => _controller.toggleType(type),
          ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final error = _controller.error;
    if (_controller.isLoading) {
      return const StatusView.loading(title: AppStrings.liveGraphLoading);
    }
    if (error != null) {
      return StatusView.error(
        title: AppStrings.liveGraphErrorTitle,
        message: error.message,
        actionLabel: AppStrings.liveGraphErrorRetry,
        onAction: () => _controller.load(),
      );
    }
    if (_controller.graph.isEmpty) {
      final filtered = _controller.types.isNotEmpty;
      return StatusView.empty(
        icon: Icons.hub_outlined,
        title: filtered
            ? AppStrings.liveGraphEmptyFilterTitle
            : AppStrings.liveGraphEmptyTitle,
        message: filtered
            ? AppStrings.liveGraphEmptyFilterMessage
            : AppStrings.liveGraphEmptyMessage,
      );
    }

    final height = (MediaQuery.sizeOf(context).height * 0.6)
        .clamp(320.0, 640.0)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: LifeGraphView(
            graph: _controller.graph,
            onNodeTap: _openNode,
            onConnect: _controller.isBusy ? null : _connect,
          ),
        ),
        if (_controller.graph.truncated) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.liveGraphTruncated,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
