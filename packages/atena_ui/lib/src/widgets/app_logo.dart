import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = AppSpacing.logoSize,
    this.semanticLabel,
    this.onTap,
    this.tooltip,
    this.icon = Icons.auto_stories_rounded,
    this.mark,
  });

  final double size;
  final String? semanticLabel;

  /// Ícone da marca. O package não conhece a identidade do projeto.
  final IconData icon;

  /// Desenho próprio da marca (vetor, imagem): ocupa o lugar de [icon] dentro
  /// do símbolo. Recebe o quadrado inteiro e desenha na proporção que quiser.
  final Widget? mark;

  /// Ação ao tocar na marca; sem ela, a logo é só visual.
  final VoidCallback? onTap;

  /// Texto do tooltip e do rótulo acessível quando a logo é tocável.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final semanticColors = AppSemanticColors.of(context);

    final badge = Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [semanticColors.brand, semanticColors.brandDeep],
          ),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child:
            mark ??
            Icon(
              icon,
              color: Theme.of(context).colorScheme.onTertiary,
              size: size * 0.52,
            ),
      ),
    );

    if (onTap == null) {
      return badge;
    }

    return Tooltip(
      message: tooltip ?? semanticLabel ?? '',
      excludeFromSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Semantics(
          button: true,
          label: tooltip ?? semanticLabel,
          excludeSemantics: true,
          child: badge,
        ),
      ),
    );
  }
}
