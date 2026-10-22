import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Campo que mostra um horário já escolhido e abre o relógio ao toque.
///
/// O horário nunca é digitado: o valor chega pronto e só muda pelo seletor do
/// projeto ([showAppTimePicker]).
///
/// ```dart
/// AppTimeField(
///   label: 'Horário (opcional)',
///   placeholder: 'Escolher horário',
///   value: time,
///   onPressed: _pickTime,
///   clearLabel: 'Remover horário',
///   onClear: () => setState(() => time = null),
/// )
/// ```
class AppTimeField extends StatelessWidget {
  const AppTimeField({
    super.key,
    required this.label,
    required this.placeholder,
    required this.value,
    required this.onPressed,
    this.clearLabel,
    this.onClear,
  });

  final String label;

  /// Texto exibido enquanto não há horário escolhido.
  final String placeholder;

  /// Horário formatado em 24 h (`09:30`), ou `null` quando não escolhido.
  final String? value;

  final VoidCallback onPressed;

  /// Rótulo do botão que limpa o horário; sem ele, não há ação de limpar.
  final String? clearLabel;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasValue = value != null;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: label,
              value: hasValue ? value : placeholder,
              child: InkWell(
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: AppSpacing.iconSize,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              value ?? placeholder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: hasValue
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (hasValue && onClear != null)
            IconButton(
              tooltip: clearLabel ?? placeholder,
              onPressed: onClear,
              icon: Icon(
                Icons.close_rounded,
                size: AppSpacing.iconSize,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
