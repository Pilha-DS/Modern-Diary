import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_button.dart';

/// Representa carregando, vazio e erro de qualquer conteúdo.
class StatusView extends StatelessWidget {
  const StatusView.loading({super.key, required this.title, this.message})
    : icon = null,
      actionLabel = null,
      onAction = null,
      isLoading = true,
      isError = false;

  const StatusView.empty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : isLoading = false,
       isError = false;

  const StatusView.error({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.cloud_off_rounded,
       isLoading = false,
       isError = true;

  final IconData? icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox.square(
              dimension: AppSpacing.xl,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          else
            Icon(
              icon ?? Icons.inbox_rounded,
              size: AppSpacing.xxl,
              color: isError ? colorScheme.error : colorScheme.onSurfaceVariant,
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ],
      ),
    );
  }
}
