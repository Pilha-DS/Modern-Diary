import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_button.dart';

enum AppConfirmVariant { warning, danger }

/// Confirmação de ação de risco. Devolve `true` só quando o usuário confirma.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  AppConfirmVariant variant = AppConfirmVariant.warning,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          AppButton(
            label: confirmLabel,
            variant: variant == AppConfirmVariant.danger
                ? AppButtonVariant.danger
                : AppButtonVariant.warning,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
