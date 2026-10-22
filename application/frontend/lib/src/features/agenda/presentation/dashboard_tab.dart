import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../../tags/data/tags_repository.dart';
import 'agenda_controller.dart';
import 'day_panel_dialog.dart';
import 'month_section.dart';

/// Início: saudação, o mês corrente e a seleção rápida das telas.
///
/// A nota do dia não fica aqui: ela é editada no modal do dia, aberto pelo
/// calendário do início.
class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.controller,
    required this.username,
    required this.quickLinks,
    required this.tagsDataSource,
    required this.toat,
    this.navigation,
  });

  final AgendaController controller;
  final String username;

  /// Telas oferecidas na seleção rápida, na ordem montada pela home.
  final List<HomeQuickLink> quickLinks;

  /// Fonte das tags usadas no painel do dia.
  final TagsDataSource tagsDataSource;
  final ToatController toat;
  final HomeNavigation? navigation;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final today = controller.today;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(AppStrings.greeting(username), style: textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.dayTitle(today),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final calendar = MonthSection(
              controller: controller,
              month: DateTime(today.year, today.month),
              hint: AppStrings.dashboardDayHint,
              // O dia abre em modal aqui mesmo: não é preciso trocar para a
              // tela de calendário para escrever a nota ou criar atividade.
              onDayOpen: (day) => showDayPanelDialog(
                context,
                controller: controller,
                tagsDataSource: tagsDataSource,
                toat: toat,
                day: day,
                navigation: navigation,
              ),
            );
            final quickMenu = _QuickNavigation(
              links: quickLinks,
              onOpen: navigation?.openSection,
            );

            if (constraints.maxWidth >= 900) {
              // O mês fica com 40% da linha (30% menor que a divisão anterior)
              // e a seleção rápida ocupa o restante.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: calendar),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(flex: 6, child: quickMenu),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                calendar,
                const SizedBox(height: AppSpacing.md),
                quickMenu,
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Menu de seleção rápida: cada linha troca a área da home.
class _QuickNavigation extends StatelessWidget {
  const _QuickNavigation({required this.links, this.onOpen});

  final List<HomeQuickLink> links;
  final ValueChanged<HomeSection>? onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppStrings.quickAccessTitle, style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.quickAccessHint,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final link in links)
            _QuickNavigationItem(link: link, onOpen: onOpen),
        ],
      ),
    );
  }
}

class _QuickNavigationItem extends StatefulWidget {
  const _QuickNavigationItem({required this.link, this.onOpen});

  final HomeQuickLink link;
  final ValueChanged<HomeSection>? onOpen;

  @override
  State<_QuickNavigationItem> createState() => _QuickNavigationItemState();
}

class _QuickNavigationItemState extends State<_QuickNavigationItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final link = widget.link;
    final onOpen = widget.onOpen;
    final isEnabled = onOpen != null;
    // Cor de destaque enquanto o ponteiro está sobre a linha: mostra que ela
    // leva para outra tela antes de qualquer clique.
    final hintColor = _hovered && isEnabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: isEnabled,
      label: link.label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          hoverColor: colorScheme.surfaceContainerHighest,
          onHover: isEnabled
              ? (value) => setState(() => _hovered = value)
              : null,
          onTap: isEnabled ? () => onOpen(link.section) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(link.icon, size: AppSpacing.iconSize, color: hintColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    link.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _hovered && isEnabled ? colorScheme.primary : null,
                      fontWeight: _hovered ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppSpacing.iconSize,
                  color: hintColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
