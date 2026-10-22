import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/audit_models.dart';

/// Mini-modal do nó do grafo de auditoria: só o que a rede já traz.
class AuditNodePreview extends StatelessWidget {
  const AuditNodePreview({super.key, required this.node});

  final AuditGraphNode node;

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
          Text(
            AppStrings.auditEntityType(node.type),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            auditNodeLabel(node),
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
                  AppStrings.auditConnectionsCount(node.degree),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            node.type == 'day'
                ? AppStrings.auditNodeDayHint
                : AppStrings.auditNodeOpenHint,
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

/// Rótulo do nó: o dia vira data curta; os demais usam o rótulo do registro.
String auditNodeLabel(AuditGraphNode node) {
  if (node.type == 'day') {
    final day = DateTime.tryParse(node.label);
    return day == null ? node.label : AppStrings.shortDate(day);
  }
  return node.label;
}
