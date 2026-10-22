import 'package:atena_ui/atena_ui.dart' as ui;
import 'package:flutter/material.dart';

import '../domain/sensitivity_level.dart';
import '../strings/app_strings.dart';

/// Escolha do nível de sensibilidade de um registro.
///
/// O widget é do `atena_ui`; aqui ele só ganha os rótulos em português do
/// Modern Diary. [includeAll] só deve ser usado como limite de leitura de uma
/// credencial: `all` não é um nível de registro.
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
    return ui.SensitivitySelector(
      label: label,
      selected: selected,
      onChanged: onChanged,
      includeAll: includeAll,
      labelOf: (level) => AppStrings.sensitivityLabelOf(level.apiValue),
    );
  }
}

/// Etiqueta do nível de um registro, usada em cartões e detalhes.
class SensitivityBadge extends StatelessWidget {
  const SensitivityBadge({super.key, required this.level});

  final SensitivityLevel level;

  @override
  Widget build(BuildContext context) {
    return ui.SensitivityBadge(
      label: AppStrings.sensitivityLabelOf(level.apiValue),
      semanticLabel: AppStrings.sensitivityBadgeLabel(level.apiValue),
    );
  }
}
