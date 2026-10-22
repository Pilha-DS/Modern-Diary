import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/life_models.dart';
import 'life_node_preview.dart';

/// Lista as conexões manuais do grafo; devolve a escolhida para remover.
///
/// As conexões que vêm de relações, metas ou do dia não aparecem aqui: elas
/// são desfeitas na origem, não no grafo.
Future<LifeGraphEdge?> showLifeLinksDialog(
  BuildContext context, {
  required LifeGraphData graph,
}) {
  return showAppDialog<LifeGraphEdge>(
    context,
    title: AppStrings.liveGraphLinksTitle,
    closeLabel: AppStrings.liveGraphLinksClose,
    child: _LifeLinksList(graph: graph),
  );
}

class _LifeLinksList extends StatelessWidget {
  const _LifeLinksList({required this.graph});

  final LifeGraphData graph;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final links = [
      for (final edge in graph.edges)
        if (edge.isCustom) edge,
    ];

    if (links.isEmpty) {
      return Text(
        AppStrings.liveGraphLinksEmpty,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.liveGraphLinksCount(links.length),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final edge in links) _LifeLinkRow(graph: graph, edge: edge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.liveGraphLinksHint,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LifeLinkRow extends StatelessWidget {
  const _LifeLinkRow({required this.graph, required this.edge});

  final LifeGraphData graph;
  final LifeGraphEdge edge;

  @override
  Widget build(BuildContext context) {
    final source = graph.nodeById(edge.source);
    final target = graph.nodeById(edge.target);
    if (source == null || target == null) {
      return const SizedBox.shrink();
    }
    final sourceLabel = lifeNodeLabel(source);
    final targetLabel = lifeNodeLabel(target);
    final semanticColors = AppSemanticColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            lifeEntityIcon(source.type),
            size: AppSpacing.iconSize,
            color: semanticColors.brandDeep,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '$sourceLabel ↔ $targetLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: AppStrings.liveGraphRemoveLinkLabel(
              sourceLabel,
              targetLabel,
            ),
            onPressed: () => Navigator.of(context).pop<LifeGraphEdge>(edge),
            icon: Icon(Icons.link_off_rounded, color: colorScheme.error),
          ),
        ],
      ),
    );
  }
}
