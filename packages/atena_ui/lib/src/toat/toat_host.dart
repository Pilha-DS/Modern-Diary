import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'toat_controller.dart';
import 'toat_message.dart';

/// Camada do TOAT: sempre no canto superior direito, acima do conteúdo.
class ToatHost extends StatelessWidget {
  const ToatHost({super.key, required this.controller, required this.child});

  final ToatController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final messages = controller.messages;
                    if (messages.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final availableWidth =
                        MediaQuery.sizeOf(context).width - AppSpacing.md * 2;
                    final width = math.min(
                      AppSpacing.maxToatWidth,
                      availableWidth,
                    );

                    return SizedBox(
                      width: width,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final message in messages)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: _ToatCard(
                                message: message,
                                onDismiss: () => controller.dismiss(message.id),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToatCard extends StatelessWidget {
  const _ToatCard({required this.message, required this.onDismiss});

  final ToatMessage message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    final (background, accent, icon) = switch (message.variant) {
      ToatVariant.success => (
        colorScheme.surface,
        semanticColors.success,
        Icons.check_circle_rounded,
      ),
      ToatVariant.info => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
        Icons.info_outline_rounded,
      ),
      ToatVariant.warning => (
        semanticColors.warningSoft,
        semanticColors.warning,
        Icons.warning_amber_rounded,
      ),
      ToatVariant.error => (
        colorScheme.errorContainer,
        colorScheme.error,
        Icons.error_outline_rounded,
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: background,
        elevation: 6,
        shadowColor: semanticColors.shadow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: AppSpacing.iconSize),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    message.message,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurface),
                  ),
                ),
              ),
              if (message.actionLabel != null && message.onAction != null)
                TextButton(
                  onPressed: () {
                    message.onAction!();
                    onDismiss();
                  },
                  child: Text(message.actionLabel!),
                ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                onPressed: onDismiss,
                icon: const Icon(
                  Icons.close_rounded,
                  size: AppSpacing.iconSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
