import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Linha de ligar/desligar: rótulo e um [Switch] que mostra o estado atual.
///
/// Tocar na linha inteira também alterna, sem depender do alvo pequeno do
/// controle. Usada onde o switch precisa ficar compacto e lado a lado com
/// outro, sem perder a leitura de ligado/desligado.
///
/// ```dart
/// AppSwitchRow(
///   label: 'Criar',
///   icon: Icons.add_rounded,
///   value: canCreate,
///   onChanged: (value) => setState(() => canCreate = value),
///   color: Theme.of(context).colorScheme.surface,
/// )
/// ```
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.color,
    this.semanticLabel,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Ícone opcional à esquerda do rótulo, na cor do estado.
  final IconData? icon;

  /// Fundo da linha; `null` mantém o fundo de quem está por baixo.
  final Color? color;

  /// Rótulo lido pelo leitor de tela; sem ele, vale o texto visível.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      toggled: value,
      label: semanticLabel ?? label,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: Material(
        color: color ?? Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.xs,
              0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTouchTarget,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: AppSpacing.iconSize,
                      color: value
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Switch(
                    value: value,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
