import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../domain/sensitivity_level.dart';
import '../strings/app_strings.dart';

/// Escolha do nível de sensibilidade de um registro.
///
/// [includeAll] só deve ser usado como limite de leitura de uma credencial:
/// `all` não é um nível de registro.
class SensitivitySelector extends StatelessWidget {
  const SensitivitySelector({
    super.key,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.includeAll = false,
  });

  final String label;
  final SensitivityLevel selected;
  final ValueChanged<SensitivityLevel> onChanged;
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
          AppChoiceOption(
            value: level,
            label: AppStrings.sensitivityLabelOf(level.apiValue),
          ),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}

/// Etiqueta do nível de um registro, usada em cartões e detalhes.
class SensitivityBadge extends StatelessWidget {
  const SensitivityBadge({super.key, required this.level});

  final SensitivityLevel level;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      icon: Icons.shield_outlined,
      label: AppStrings.sensitivityLabelOf(level.apiValue),
      semanticLabel: AppStrings.sensitivityBadgeLabel(level.apiValue),
    );
  }
}
