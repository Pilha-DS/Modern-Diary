import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Barra de progresso do projeto, com a contagem ao lado (`2/5`).
///
/// O [value] é sempre uma fração de 0 a 1; a contagem e o texto vêm de fora,
/// para o package não conhecer o idioma nem a regra de negócio.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.label,
    this.semanticLabel,
  });

  final double value;
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel,
      value: label,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: LinearProgressIndicator(
                value: clamped,
                minHeight: AppSpacing.sm,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
