import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/life_models.dart';

/// Rótulo do nó: título do registro, data do dia e "Sem título" na nota.
String lifeNodeLabel(LifeGraphNode node) {
  final title = node.title?.trim();
  if (title != null && title.isNotEmpty) {
    return title;
  }
  if (node.type == LifeEntityType.day && node.day != null) {
    return AppStrings.shortDate(node.day!);
  }
  if (node.type == LifeEntityType.note) {
    return AppStrings.noteUntitled;
  }
  return node.ref;
}

/// Nome do tipo, como aparece no resumo e no filtro.
String lifeEntityTypeLabel(LifeEntityType type) {
  return AppStrings.auditEntityType(type.apiValue);
}

/// Ícone do tipo no filtro e no resumo do nó.
IconData lifeEntityIcon(LifeEntityType type) {
  return switch (type) {
    LifeEntityType.knowledge => Icons.lightbulb_outline_rounded,
    LifeEntityType.goal => Icons.flag_outlined,
    LifeEntityType.note => Icons.sticky_note_2_outlined,
    LifeEntityType.activity => Icons.checklist_rounded,
    LifeEntityType.day => Icons.calendar_today_outlined,
  };
}

/// Mini-modal do nó do grafo de vida: tipo, rótulo e conexões.
class LifeNodePreview extends StatelessWidget {
  const LifeNodePreview({
    super.key,
    required this.node,
    required this.connections,
  });

  final LifeGraphNode node;
  final int connections;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppSpacing.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                lifeEntityIcon(node.type),
                size: AppSpacing.iconSize,
                color: semanticColors.brandDeep,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                lifeEntityTypeLabel(node.type),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            lifeNodeLabel(node),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.share_outlined,
                size: AppSpacing.iconSize,
                color: semanticColors.brandDeep,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  AppStrings.auditConnectionsCount(connections),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            AppStrings.liveGraphNodeOpenHint,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
