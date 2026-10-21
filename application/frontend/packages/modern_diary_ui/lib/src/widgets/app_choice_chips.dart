import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_chip.dart';

/// Uma das escolhas oferecidas em [AppChoiceChips].
class AppChoiceOption<T> {
  const AppChoiceOption({
    required this.value,
    required this.label,
    this.semanticLabel,
  });

  final T value;
  final String label;

  /// Rótulo lido pelo leitor de tela; sem ele, vale o texto visível.
  final String? semanticLabel;
}

/// Escolha única entre poucas opções, exibida como etiquetas lado a lado.
///
/// Não conhece a regra do dado: recebe os valores e devolve a escolha.
///
/// ```dart
/// AppChoiceChips<String>(
///   label: 'Prioridade',
///   options: const [
///     AppChoiceOption(value: 'low', label: 'Baixa'),
///     AppChoiceOption(value: 'high', label: 'Alta'),
///   ],
///   selected: priority,
///   onChanged: (value) => setState(() => priority = value),
/// )
/// ```
class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<AppChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in options)
              AppChip(
                label: option.label,
                semanticLabel: option.semanticLabel,
                isSelected: option.value == selected,
                onTap: option.value == selected
                    ? null
                    : () => onChanged(option.value),
              ),
          ],
        ),
      ],
    );
  }
}
