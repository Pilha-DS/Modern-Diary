import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum InlineMessageVariant { info, warning, error }

/// Mensagem no próprio conteúdo, para erro que exige decisão ou aviso fixo.
/// Não substitui o TOAT.
class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.variant = InlineMessageVariant.info,
  });

  final String message;
  final InlineMessageVariant variant;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    final (background, foreground, icon) = switch (variant) {
      InlineMessageVariant.info => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
        Icons.info_outline_rounded,
      ),
      InlineMessageVariant.warning => (
        semanticColors.warningSoft,
        semanticColors.warning,
        Icons.warning_amber_rounded,
      ),
      InlineMessageVariant.error => (
        colorScheme.errorContainer,
        colorScheme.error,
        Icons.error_outline_rounded,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppSpacing.iconSize, color: foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
