import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/tag_models.dart';

extension TagColor on Tag {
  Color get color => AppTagColors.parse(colorHex);
}

/// Etiqueta de uma tag, com o ponto na cor escolhida.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.tag,
    this.onTap,
    this.onDeleted,
    this.deleteLabel,
  });

  final Tag tag;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: tag.name,
      accent: tag.color,
      onTap: onTap,
      onDeleted: onDeleted,
      deleteLabel: deleteLabel ?? AppStrings.tagRemoveLabel(tag.name),
      semanticLabel: onTap == null
          ? tag.name
          : AppStrings.tagOpenLabel(tag.name),
    );
  }
}

/// Lista de tags em etiquetas que quebram linha conforme a largura.
class TagChips extends StatelessWidget {
  const TagChips({
    super.key,
    required this.tags,
    this.onTap,
    this.onRemove,
    this.removeLabel,
  });

  final List<Tag> tags;
  final ValueChanged<Tag>? onTap;
  final ValueChanged<Tag>? onRemove;
  final String Function(Tag tag)? removeLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final tag in tags)
          TagChip(
            tag: tag,
            onTap: onTap == null ? null : () => onTap!(tag),
            onDeleted: onRemove == null ? null : () => onRemove!(tag),
            deleteLabel: removeLabel?.call(tag),
          ),
      ],
    );
  }
}

/// Tags que cabem em uma única linha; o restante vira o atalho "Ver mais".
///
/// A medida usa a mesma fonte e o mesmo espaçamento da etiqueta, então o
/// corte acompanha a largura disponível e o tamanho do texto do sistema.
class TagChipsOverflow extends StatelessWidget {
  const TagChipsOverflow({
    super.key,
    required this.tags,
    this.onTap,
    this.onShowAll,
  });

  final List<Tag> tags;
  final ValueChanged<Tag>? onTap;
  final VoidCallback? onShowAll;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final visible = _visibleCount(context, constraints.maxWidth);
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final tag in tags.take(visible))
              TagChip(
                tag: tag,
                onTap: onTap == null ? null : () => onTap!(tag),
              ),
            if (visible < tags.length)
              AppChip(
                label: AppStrings.knowledgeTagsShowAll,
                onTap: onShowAll,
                semanticLabel: AppStrings.knowledgeTagsShowAll,
              ),
          ],
        );
      },
    );
  }

  int _visibleCount(BuildContext context, double maxWidth) {
    final style =
        Theme.of(context).textTheme.bodySmall
            ?.copyWith(fontWeight: FontWeight.w600) ??
        const TextStyle();
    final textScaler = MediaQuery.textScalerOf(context);

    double chipWidth(String label) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: Directionality.of(context),
        maxLines: 1,
        textScaler: textScaler,
      )..layout();
      // Padding da etiqueta (8 + 8) + ponto da tag (8) + espaço do ponto (4).
      return painter.width + AppSpacing.md + AppSpacing.sm + AppSpacing.xs;
    }

    final widths = [for (final tag in tags) chipWidth(tag.name)];
    if (!maxWidth.isFinite) {
      return tags.length;
    }

    double usedBy(int count) {
      var total = 0.0;
      for (var index = 0; index < count; index++) {
        total += widths[index] + (index == 0 ? 0 : AppSpacing.sm);
      }
      return total;
    }

    var visible = 0;
    while (visible < widths.length && usedBy(visible + 1) <= maxWidth) {
      visible++;
    }

    if (visible < widths.length) {
      final moreWidth = chipWidth(AppStrings.knowledgeTagsShowAll);
      while (visible > 0 &&
          usedBy(visible) + AppSpacing.sm + moreWidth > maxWidth) {
        visible--;
      }
    }

    return visible;
  }
}
