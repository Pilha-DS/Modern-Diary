import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Linha com rótulo, valor atual e [Slider], usada para ajustes contínuos
/// (força do grafo, opacidade e afins).
///
/// O valor exibido ao lado do rótulo também é o texto lido pelo leitor de
/// tela, então quem usa a tela sem enxergar ouve a grandeza e o valor juntos.
///
/// ```dart
/// AppSliderRow(
///   label: 'Repulsão',
///   icon: Icons.open_in_full_rounded,
///   value: settings.repulsion,
///   min: 0.3,
///   max: 2.4,
///   valueLabel: '1,0×',
///   onChanged: (value) => update(settings.copyWith(repulsion: value)),
/// )
/// ```
class AppSliderRow extends StatelessWidget {
  const AppSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.valueLabel,
    this.icon,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  /// Valor já formatado para leitura; sem ele, o número cru aparece no leitor
  /// de tela.
  final String? valueLabel;

  /// Ícone opcional à esquerda do rótulo.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final safeValue = value.clamp(min, max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppSpacing.iconSize,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (valueLabel != null)
              Text(
                valueLabel!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        Slider(
          value: safeValue,
          min: min,
          max: max,
          label: valueLabel,
          semanticFormatterCallback: (_) {
            final shown = valueLabel;
            return shown == null ? label : '$label: $shown';
          },
          onChanged: onChanged,
        ),
      ],
    );
  }
}
