import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Etiqueta compacta, sem borda, para links, conexões e marcadores.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.accent,
    this.onTap,
    this.onDeleted,
    this.deleteLabel,
    this.isSelected = false,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;

  /// Cor de destaque da etiqueta, usada para identificar tags.
  final Color? accent;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final String? deleteLabel;
  final bool isSelected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final background = isSelected
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final foreground = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (accent != null) ...[
          Container(
            width: AppSpacing.sm,
            height: AppSpacing.sm,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        if (icon != null) ...[
          Icon(icon, size: AppSpacing.iconSize, color: foreground),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onDeleted != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Tooltip(
            message: deleteLabel ?? label,
            child: Semantics(
              button: true,
              label: deleteLabel ?? label,
              excludeSemantics: true,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onDeleted,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: AppSpacing.iconSize - 4,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final chip = Container(
      constraints: const BoxConstraints(minHeight: AppSpacing.chipHeight),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      // O fundo do chip cobre o `Material` de baixo; sem esta camada o hover
      // e o toque não apareceriam e a etiqueta não pareceria clicável.
      child: Material(
        type: MaterialType.transparency,
        child: onTap == null
            ? Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: content,
              )
            : InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: content,
                ),
              ),
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      selected: isSelected,
      label: semanticLabel,
      // O rótulo próprio substitui o texto; com ação de excluir, os filhos
      // continuam expostos para o leitor anunciar as duas ações.
      excludeSemantics: semanticLabel != null && onDeleted == null,
      child: chip,
    );
  }
}
