import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Linha de informação do rodapé (contato, site, local etc.).
class AppFooterItem {
  const AppFooterItem({
    required this.icon,
    required this.text,
    this.semanticLabel,
  });

  final IconData icon;
  final String text;

  /// Rótulo lido pelo leitor de tela; sem ele, usa [text].
  final String? semanticLabel;
}

/// Rodapé padrão do projeto: identificação de quem fez e como falar.
///
/// Os dados vêm por parâmetro — o rodapé não conhece a aplicação e não busca
/// nada sozinho.
///
/// ```dart
/// AppFooter(
///   appName: 'Modern Diary',
///   tagline: 'Seu dia, organizado.',
///   note: 'Feito por Jonathan',
///   items: const [
///     AppFooterItem(icon: Icons.mail_outline_rounded, text: 'eu@exemplo.com'),
///   ],
/// )
/// ```
class AppFooter extends StatelessWidget {
  const AppFooter({
    super.key,
    required this.appName,
    this.tagline,
    this.note,
    this.items = const [],
  });

  final String appName;
  final String? tagline;

  /// Linha de crédito, por exemplo "Feito por Fulano".
  final String? note;
  final List<AppFooterItem> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 3,
            decoration: BoxDecoration(
              color: semanticColors.brand.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            appName,
            textAlign: TextAlign.center,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (tagline != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              tagline!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
          ],
          if (items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                for (final item in items)
                  Semantics(
                    label: item.semanticLabel ?? item.text,
                    excludeSemantics: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: AppSpacing.iconSize - 2,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          item.text,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
