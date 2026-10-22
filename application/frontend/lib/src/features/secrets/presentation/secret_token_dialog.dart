import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/secret_models.dart';

/// Mostra o token recém-criado. Ele não é recuperável depois: esta é a única
/// chance de copiar.
Future<void> showSecretTokenDialog(
  BuildContext context, {
  required SecretCreation creation,
  required ValueChanged<String> onCopy,
}) {
  return showAppDialog<void>(
    context,
    title: AppStrings.secretTokenTitle,
    closeLabel: AppStrings.close,
    maxWidth: 520,
    child: _SecretTokenBody(creation: creation, onCopy: onCopy),
  );
}

class _SecretTokenBody extends StatelessWidget {
  const _SecretTokenBody({required this.creation, required this.onCopy});

  final SecretCreation creation;
  final ValueChanged<String> onCopy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          creation.secret.name,
          style: textTheme.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.secretHint(creation.secret.tokenHint),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const InlineMessage(
          message: AppStrings.secretTokenWarning,
          variant: InlineMessageVariant.warning,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.secretTokenLabel, style: textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: SelectableText(
            creation.token,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppButton(
              label: AppStrings.secretTokenCopy,
              icon: Icons.copy_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => onCopy(creation.token),
            ),
            AppButton(
              label: AppStrings.secretTokenDone,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }
}
