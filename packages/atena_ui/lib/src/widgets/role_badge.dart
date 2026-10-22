import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, required this.label});

  final String role;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    final (background, foreground) = switch (role) {
      'ADMIN' => (semanticColors.brandSoft, semanticColors.brand),
      'MODERATOR' => (colorScheme.primaryContainer, colorScheme.primary),
      _ => (colorScheme.secondaryContainer, colorScheme.onSecondaryContainer),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
