import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_logo.dart';
import 'app_surface.dart';

/// Item do menu escondido do avatar.
class AppHeaderMenuItem {
  const AppHeaderMenuItem({
    required this.icon,
    required this.label,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}

/// Cabeçalho padrão das áreas: identidade à esquerda e perfil à direita.
///
/// O avatar mostra a foto ([avatarImage]) quando existe; sem foto, mostra as
/// iniciais de [avatarLabel]. Ao tocar, abre o menu escondido com os [menuItems]
/// — é por ele que o usuário chega às configurações. Sem itens, o avatar é só
/// uma marca visual. Com [onLogoPressed], a marca da esquerda vira um atalho
/// (o app usa para voltar ao início).
///
/// ```dart
/// AppHeader(
///   title: 'Modern Diary',
///   subtitle: 'jonathan',
///   avatarLabel: 'jonathan',
///   avatarTooltip: 'Perfil e configurações',
///   logoTooltip: 'Ir para Início',
///   onLogoPressed: goToDashboard,
///   trailing: RoleBadge(role: 'USER', label: 'USUÁRIO'),
///   menuItems: [
///     AppHeaderMenuItem(
///       icon: Icons.settings_outlined,
///       label: 'Configurações básicas',
///       onSelected: openSettings,
///     ),
///   ],
/// )
/// ```
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.avatarLabel,
    this.avatarImage,
    this.avatarTooltip,
    this.menuItems = const [],
    this.avatarSize = 44,
    this.onLogoPressed,
    this.logoTooltip,
  });

  final String title;
  final String? subtitle;

  /// Bloco à direita, antes do avatar (por exemplo, o selo de role).
  final Widget? trailing;

  /// Texto usado para as iniciais quando não há foto.
  final String? avatarLabel;

  /// Foto do usuário; quando nula, o avatar mostra as iniciais.
  final ImageProvider? avatarImage;

  final String? avatarTooltip;
  final List<AppHeaderMenuItem> menuItems;
  final double avatarSize;

  /// Ação ao tocar na marca da esquerda (levar para o início).
  final VoidCallback? onLogoPressed;

  /// Texto do tooltip da marca quando ela é tocável.
  final String? logoTooltip;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppSpacing.radiusLg,
      child: Row(
        children: [
          AppLogo(
            semanticLabel: title,
            onTap: onLogoPressed,
            tooltip: logoTooltip,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          const SizedBox(width: AppSpacing.sm),
          _AvatarMenu(
            label: avatarLabel ?? title,
            image: avatarImage,
            tooltip: avatarTooltip,
            size: avatarSize,
            items: menuItems,
          ),
        ],
      ),
    );
  }
}

class _AvatarMenu extends StatelessWidget {
  const _AvatarMenu({
    required this.label,
    required this.image,
    required this.tooltip,
    required this.size,
    required this.items,
  });

  final String label;
  final ImageProvider? image;
  final String? tooltip;
  final double size;
  final List<AppHeaderMenuItem> items;

  /// Primeira e última palavra do nome, no máximo duas letras.
  String get _initials {
    final words = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return (words.first.substring(0, 1) + words.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);
    final photo = image;

    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: photo == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [semanticColors.brand, semanticColors.brandDeep],
              )
            : null,
        image: photo == null
            ? null
            : DecorationImage(image: photo, fit: BoxFit.cover),
        border: Border.all(color: colorScheme.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: photo == null
          ? Text(
              _initials,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colorScheme.onTertiary,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );

    final semanticLabel = tooltip ?? label;

    if (items.isEmpty) {
      return Semantics(
        image: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: avatar,
      );
    }

    return Tooltip(
      message: semanticLabel,
      // O rótulo acessível vem do Semantics abaixo; sem isso o leitor de tela
      // anuncia o nome duas vezes.
      excludeFromSemantics: true,
      child: PopupMenuButton<AppHeaderMenuItem>(
        tooltip: '',
        position: PopupMenuPosition.under,
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        onSelected: (item) => item.onSelected(),
        itemBuilder: (context) => [
          for (final item in items)
            PopupMenuItem<AppHeaderMenuItem>(
              value: item,
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: AppSpacing.iconSize,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: Text(item.label)),
                ],
              ),
            ),
        ],
        child: Semantics(
          button: true,
          label: semanticLabel,
          excludeSemantics: true,
          child: avatar,
        ),
      ),
    );
  }
}
