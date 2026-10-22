import 'package:flutter/material.dart';

import '../widgets/app_choice_chips.dart';
import '../widgets/app_chip.dart';
import 'sensitivity_level.dart';

/// Escolha do nível de sensibilidade de um registro.
///
/// Os rótulos vêm de fora (`labelOf`), porque o package não conhece o idioma.
/// [includeAll] só deve ser usado como limite de leitura de uma credencial:
/// `all` não é um nível de registro.
class SensitivitySelector extends StatelessWidget {
  const SensitivitySelector({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    required this.labelOf,
    this.includeAll = false,
  });

  final String label;
  final SensitivityLevel selected;
  final ValueChanged<SensitivityLevel> onChanged;
  final String Function(SensitivityLevel level) labelOf;
  final bool includeAll;

  @override
  Widget build(BuildContext context) {
    final levels = includeAll
        ? SensitivityLevel.values
        : SensitivityLevel.dataLevels;

    return AppChoiceChips<SensitivityLevel>(
      label: label,
      options: [
        for (final level in levels)
          AppChoiceOption(value: level, label: labelOf(level)),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}

/// Etiqueta do nível de um registro, usada em cartões e detalhes.
class SensitivityBadge extends StatelessWidget {
  const SensitivityBadge({
    super.key,
    required this.label,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      icon: Icons.shield_outlined,
      label: label,
      semanticLabel: semanticLabel ?? label,
    );
  }
}
