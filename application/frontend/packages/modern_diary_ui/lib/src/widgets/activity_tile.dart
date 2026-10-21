import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum ActivityPriority { low, medium, high }

/// Linha de uma atividade: concluir, ler e excluir.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.title,
    required this.priority,
    required this.priorityLabel,
    required this.isDone,
    this.timeLabel,
    this.sensitivityLabel,
    this.sensitivityActionLabel,
    this.toggleLabel,
    this.deleteLabel,
    this.onToggle,
    this.onDelete,
    this.onSensitivityPressed,
    this.isBusy = false,
  });

  final String title;
  final ActivityPriority priority;
  final String priorityLabel;
  final bool isDone;
  final String? timeLabel;

  /// Nível de sensibilidade já traduzido; sem rótulo, a linha não mostra.
  final String? sensitivityLabel;

  /// Rótulo do botão que abre a escolha do nível; sem ele, o botão não aparece.
  final String? sensitivityActionLabel;
  final String? toggleLabel;
  final String? deleteLabel;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onSensitivityPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);
    final textTheme = Theme.of(context).textTheme;
    final canToggle = onToggle != null && !isBusy;

    final check = InkWell(
      customBorder: const CircleBorder(),
      onTap: canToggle ? onToggle : null,
      child: Semantics(
        button: true,
        label: toggleLabel,
        onTap: canToggle ? onToggle : null,
        excludeSemantics: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: AppSpacing.xl,
          height: AppSpacing.xl,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? semanticColors.brandSoft
                : colorScheme.surfaceContainerHighest,
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.circle_outlined,
            size: AppSpacing.iconSize,
            color: isDone
                ? semanticColors.brandDeep
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    return Opacity(
      opacity: isBusy ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            check,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (timeLabel != null) _InfoPill(label: timeLabel!),
                      if (sensitivityLabel != null)
                        _InfoPill(
                          label: sensitivityLabel!,
                          icon: Icons.shield_outlined,
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _priorityColor(colorScheme),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            priorityLabel,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (onSensitivityPressed != null)
              IconButton(
                tooltip: sensitivityActionLabel,
                onPressed: isBusy ? null : onSensitivityPressed,
                icon: const Icon(
                  Icons.shield_outlined,
                  size: AppSpacing.iconSize,
                ),
              ),
            if (onDelete != null)
              IconButton(
                tooltip: deleteLabel,
                onPressed: isBusy ? null : onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: AppSpacing.iconSize,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _priorityColor(ColorScheme colorScheme) {
    return switch (priority) {
      ActivityPriority.high => colorScheme.primary,
      ActivityPriority.medium => colorScheme.onSurfaceVariant,
      ActivityPriority.low => colorScheme.outline,
    };
  }
}

/// Etiqueta de apoio da linha: horário ou nível já traduzido.
class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final iconData = icon;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconData != null) ...[
            Icon(iconData, size: 12, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}
