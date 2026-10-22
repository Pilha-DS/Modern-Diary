import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart' hide SensitivityBadge, SensitivitySelector;

import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../../tags/presentation/tag_chips.dart';
import '../domain/knowledge_models.dart';

/// Mini-modal aberto ao lado do nó no grafo de conhecimentos.
///
/// Mostra só o que a rede já traz — nível, tags e conexões —, para o hover não
/// disparar consulta: o detalhe completo continua no clique.
class KnowledgeNodePreview extends StatelessWidget {
  const KnowledgeNodePreview({super.key, required this.node});

  final KnowledgeNodeData node;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    return Semantics(
      container: true,
      label: AppStrings.knowledgeGraphNodeTooltip(
        connections: node.degree,
        sensitivity: AppStrings.sensitivityLabelOf(node.sensitivity.apiValue),
        tags: [for (final tag in node.tags) tag.name],
      ),
      excludeSemantics: true,
      child: AppSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppSpacing.radiusMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              node.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SensitivityBadge(level: node.sensitivity),
                for (final tag in node.tags.take(3)) TagChip(tag: tag),
              ],
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
                    AppStrings.knowledgeRelationsCount(node.degree),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (node.tags.length > 3) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.knowledgeNodeMoreTags(node.tags.length - 3),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.knowledgeNodeOpenHint,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
