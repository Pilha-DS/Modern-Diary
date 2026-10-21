import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../domain/note_models.dart';

/// Cartão de uma nota na lista.
///
/// A prévia vem do servidor já cortada; o cartão nunca carrega o markdown
/// inteiro. Nota fixada ganha a sombra azul de destaque e o selo "Fixada".
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.isBusy,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
  });

  final NoteSummary note;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);
    final title = note.hasTitle ? note.title! : AppStrings.noteUntitled;

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      shadowColor: note.isPinned ? semanticColors.highlightShadow : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  onTap: isBusy ? null : onOpen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      title,
                      style: textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: note.isPinned
                    ? AppStrings.noteUnpinAction
                    : AppStrings.notePinAction,
                onPressed: isBusy ? null : onTogglePin,
                icon: Icon(
                  note.isPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  size: AppSpacing.iconSize,
                  color: note.isPinned ? colorScheme.primary : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            onTap: isBusy ? null : onOpen,
            child: Text(
              note.preview.trim(),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (note.isPinned)
                const AppChip(
                  icon: Icons.push_pin_rounded,
                  label: AppStrings.notePinnedBadge,
                ),
              SensitivityBadge(level: note.sensitivity),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Semantics(
                label: AppStrings.noteUpdatedAt(note.updatedAt.toLocal()),
                excludeSemantics: true,
                child: Text(
                  AppStrings.shortDate(note.updatedAt.toLocal()),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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
                      tooltip: AppStrings.editNote,
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: AppSpacing.iconSize,
                      ),
                    ),
                    IconButton(
                      tooltip: AppStrings.noteDeleteAction,
                      onPressed: onDelete,
                      color: semanticColors.warning,
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
