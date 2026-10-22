import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, ghost, danger, warning }

/// Botão único do projeto: sem borda, com estado de carregamento que bloqueia
/// o segundo toque.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (backgroundColor, foregroundColor) = _colors(
      colorScheme,
      AppSemanticColors.of(context),
    );
    final isDisabled = isLoading || onPressed == null;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox.square(
            dimension: AppSpacing.iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        else if (icon != null)
          Icon(icon, size: AppSpacing.iconSize),
        if (isLoading || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final button = FilledButton(
      onPressed: isDisabled ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor.withValues(alpha: 0.55),
        disabledForegroundColor: foregroundColor.withValues(alpha: 0.8),
        elevation: 0,
        minimumSize: const Size(0, AppSpacing.minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      child: content,
    );

    if (!expanded) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }

  (Color, Color) _colors(
    ColorScheme colorScheme,
    AppSemanticColors semanticColors,
  ) {
    switch (variant) {
      case AppButtonVariant.primary:
        return (colorScheme.primary, colorScheme.onPrimary);
      case AppButtonVariant.secondary:
        return (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        );
      case AppButtonVariant.ghost:
        return (Colors.transparent, colorScheme.primary);
      case AppButtonVariant.danger:
        return (colorScheme.error, colorScheme.onError);
      case AppButtonVariant.warning:
        return (semanticColors.warning, colorScheme.surface);
    }
  }
}
