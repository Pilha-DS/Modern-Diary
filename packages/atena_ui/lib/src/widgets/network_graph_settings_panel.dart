import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_slider_row.dart';
import 'app_surface.dart';
import 'network_graph.dart';

/// Textos do painel de ajustes da rede, que vêm da aplicação.
class NetworkGraphSettingsLabels {
  const NetworkGraphSettingsLabels({
    required this.repulsion,
    required this.linkDistance,
    required this.gravity,
    required this.dragHint,
  });

  final String repulsion;
  final String linkDistance;
  final String gravity;
  final String dragHint;
}

/// Painel "Ajustes da rede" do [NetworkGraph]: repulsão, distância das
/// conexões, gravidade e a dica de arrasto.
///
/// Não guarda estado: o chamador escuta o [NetworkGraphController] e
/// reconstrói o painel quando os ajustes mudam.
///
/// ```dart
/// NetworkGraphSettingsPanel(
///   controller: controller,
///   labels: NetworkGraphSettingsLabels(...),
///   maxWidth: 280,
///   maxHeight: constraints.maxHeight,
/// )
/// ```
class NetworkGraphSettingsPanel extends StatelessWidget {
  const NetworkGraphSettingsPanel({
    super.key,
    required this.controller,
    required this.labels,
    required this.maxWidth,
    required this.maxHeight,
  });

  final NetworkGraphController controller;
  final NetworkGraphSettingsLabels labels;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: maxWidth,
      child: AppSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderRadius: AppSpacing.radiusMd,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(0, maxHeight - 2 * AppSpacing.md),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSliderRow(
                  label: labels.repulsion,
                  icon: Icons.open_in_full_rounded,
                  value: settings.repulsion,
                  min: NetworkGraphSettings.minRepulsion,
                  max: NetworkGraphSettings.maxRepulsion,
                  valueLabel: _factorLabel(settings.repulsion),
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(repulsion: value),
                  ),
                ),
                AppSliderRow(
                  label: labels.linkDistance,
                  icon: Icons.share_outlined,
                  value: settings.linkDistance,
                  min: NetworkGraphSettings.minLinkDistance,
                  max: NetworkGraphSettings.maxLinkDistance,
                  valueLabel: _factorLabel(settings.linkDistance),
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(linkDistance: value),
                  ),
                ),
                AppSliderRow(
                  label: labels.gravity,
                  icon: Icons.center_focus_weak_rounded,
                  value: settings.gravity,
                  min: NetworkGraphSettings.minGravity,
                  max: NetworkGraphSettings.maxGravity,
                  valueLabel: _factorLabel(settings.gravity),
                  onChanged: (value) => controller.updateSettings(
                    settings.copyWith(gravity: value),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  labels.dragHint,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _factorLabel(double value) =>
      '${value.toStringAsFixed(1).replaceAll('.', ',')}×';
}
