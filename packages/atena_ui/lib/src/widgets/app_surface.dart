import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Superfície sólida com sombra suave, sem borda visível.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.borderRadius = AppSpacing.radiusLg,
    this.elevated = true,
    this.shadowColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool elevated;

  /// Troca a cor da sombra padrão; usada no destaque do mês atual.
  final Color? shadowColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: shadowColor ?? semanticColors.shadow,
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      // A cor sólida do cartão cobre o `Material` de baixo: esta camada
      // transparente devolve o hover/toque para os botões do conteúdo.
      child: Material(
        type: MaterialType.transparency,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
