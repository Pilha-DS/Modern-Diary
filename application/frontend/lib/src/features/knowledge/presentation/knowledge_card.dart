import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart' hide SensitivityBadge, SensitivitySelector;

import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../../tags/domain/tag_models.dart';
import '../../tags/presentation/tag_chips.dart';
import '../domain/knowledge_models.dart';

/// Cartão compacto de um conhecimento.
///
/// Conteúdo em uma coluna: nome, nível, as coleções (metas, links, conexões),
/// a quantidade de conexões, as tags e a data de criação. O cartão é estreito e
/// alto, então ocupa pouco da linha e deixa a lista densa. Cada coleção abre em
/// modal, onde também pode ser alimentada.
class KnowledgeCard extends StatelessWidget {
  const KnowledgeCard({
    super.key,
    required this.item,
    required this.isBusy,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenGoals,
    required this.onOpenLinks,
    required this.onOpenConnections,
    this.onOpenTag,
    this.onShowAllTags,
  });

  final KnowledgeItem item;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenGoals;
  final VoidCallback onOpenLinks;
  final VoidCallback onOpenConnections;

  /// Clique numa tag leva ao menu de tags.
  final ValueChanged<Tag>? onOpenTag;

  /// "Ver mais" das tags, quando elas não cabem na largura do cartão.
  final VoidCallback? onShowAllTags;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final createdAt = item.createdAt.toLocal();

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nome e nível na mesma linha: o título fica com o espaço que sobra
          // e o nível acompanha o nome sem empurrar o conteúdo.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  onTap: isBusy ? null : onOpen,
                  child: Text(
                    item.title,
                    style: textTheme.titleSmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              SensitivityBadge(level: item.sensitivity),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          if (item.hasContent) ...[
            Text(
              item.content!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          _CardAction(
            icon: Icons.flag_outlined,
            label: AppStrings.knowledgeGoalsCell,
            onPressed: isBusy ? null : onOpenGoals,
          ),
          _CardAction(
            icon: Icons.link_rounded,
            label: AppStrings.knowledgeLinksCell,
            onPressed: isBusy ? null : onOpenLinks,
          ),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _CardAction(
                icon: Icons.hub_outlined,
                label: AppStrings.knowledgeConnectionsCell,
                onPressed: isBusy ? null : onOpenConnections,
              ),
              _CardStat(
                label: AppStrings.knowledgeQuantityLabel,
                value: '${item.relations.length}',
                semanticLabel: AppStrings.knowledgeRelationsCount(
                  item.relations.length,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (item.tags.isNotEmpty)
            SizedBox(
              // Altura fixa da linha de etiquetas: a grade iguala a altura dos
              // cartões medindo o conteúdo, e o corte de tags usa layout, que
              // não informa altura intrínseca.
              height: math.max(
                AppSpacing.chipHeight,
                MediaQuery.textScalerOf(context).scale(16) + AppSpacing.sm,
              ),
              child: TagChipsOverflow(
                tags: item.tags,
                onTap: onOpenTag,
                onShowAll: onShowAllTags,
              ),
            ),
          // A grade iguala a altura dos cartões da linha; o espaço extra fica
          // aqui, e a data com as ações continua no rodapé de todos.
          const Spacer(),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _CardDate(createdAt: createdAt),
              if (isBusy)
                const SizedBox.square(
                  dimension: AppSpacing.iconSize,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: AppStrings.knowledgeEditAction,
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: AppSpacing.iconSize,
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.knowledgeDeleteAction,
                      onPressed: onDelete,
                      color: colorScheme.error,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: AppSpacing.iconSize,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ação de uma coleção: ícone e rótulo, alinhados à esquerda.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AppSpacing.iconSize),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, AppSpacing.minTouchTarget),
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
    );
  }
}

class _CardStat extends StatelessWidget {
  const _CardStat({
    required this.label,
    required this.value,
    required this.semanticLabel,
  });

  final String label;
  final String value;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// Data e hora em uma linha, no rodapé do cartão.
class _CardDate extends StatelessWidget {
  const _CardDate({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Semantics(
      label: AppStrings.knowledgeCreatedAt(createdAt),
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          Text(AppStrings.shortDate(createdAt), style: muted),
          Text(AppStrings.shortTime(createdAt), style: muted),
        ],
      ),
    );
  }
}
