import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../../tags/presentation/tag_chips.dart';
import '../domain/agenda_models.dart';
import 'agenda_controller.dart';

/// Prévia do dia exibida ao lado da célula no calendário.
///
/// Mostra o feriado, o nível e as tags do dia, as notas (com o começo de cada
/// uma) e as atividades. Lê o dia sob demanda e usa o resumo do calendário
/// enquanto a leitura não chega, para nunca piscar vazio.
class AgendaDayPreview extends StatefulWidget {
  const AgendaDayPreview({
    super.key,
    required this.controller,
    required this.day,
  });

  final AgendaController controller;
  final DateTime day;

  @override
  State<AgendaDayPreview> createState() => _AgendaDayPreviewState();
}

class _AgendaDayPreviewState extends State<AgendaDayPreview> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AgendaDayPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(oldWidget.day, widget.day)) {
      _load();
    }
  }

  void _load() {
    final day = widget.day;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.controller.loadPreview(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final day = widget.day;
    final loaded = widget.controller.previewDay(day);
    final summary = widget.controller.summaryFor(day);
    final holiday = loaded?.holiday ?? summary?.holiday;
    final tags = loaded?.tags ?? summary?.tags ?? const [];
    final level = loaded?.sensitivity;
    final notes = loaded?.notes ?? const <AgendaNote>[];
    final activities = loaded?.activities ?? const <AgendaActivity>[];
    final notesEmptyLabel = loaded == null && (summary?.hasNote ?? false)
        ? AppStrings.dayPreviewLoading
        : AppStrings.noteEmpty;

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderRadius: AppSpacing.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.dayTitle(day),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (holiday != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _HolidayLine(name: holiday),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (level != null)
                SensitivityBadge(level: level)
              else
                AppChip(
                  icon: Icons.shield_outlined,
                  label: AppStrings.daySensitivityNone,
                ),
              for (final tag in tags.take(3))
                AppChip(label: tag.name, accent: tag.color),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _SectionTitle(
            label: AppStrings.noteTitle,
            count: notes.isEmpty ? null : '${notes.length}',
          ),
          if (notes.isNotEmpty)
            for (final note in notes.take(2))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _snippet(note.content),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
          else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                notesEmptyLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (notes.length > 2)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                AppStrings.noteMore(notes.length - 2),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          _SectionTitle(
            label: AppStrings.activitiesTitle,
            count: activities.isEmpty
                ? (summary?.activitiesTotal ?? 0) == 0
                      ? null
                      : '${summary!.activitiesTotal}'
                : '${activities.length}',
          ),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                AppStrings.dayPreviewNoActivities,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final activity in activities.take(3))
              _ActivityLine(activity: activity),
        ],
      ),
    );
  }

  String _snippet(String content) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map(_stripMarkdown)
        .where((line) => line.isNotEmpty);
    final text = lines.take(2).join(' ');
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  String _stripMarkdown(String line) {
    return line
        .replaceAll(RegExp(r'^#{1,3}\s+'), '')
        .replaceAll(RegExp(r'^>\s+'), '')
        .replaceAll(RegExp(r'^[-*]\s+\[[ xX]\]\s+'), '')
        .replaceAll(RegExp(r'^[-*]\s+'), '')
        .replaceAll(RegExp(r'^\d+\.\s+'), '')
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]+\)'),
          (match) => match[1]!,
        )
        .replaceAll('`', '');
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, this.count});

  final String label;
  final String? count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count != null)
          Text(
            count!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _HolidayLine extends StatelessWidget {
  const _HolidayLine({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final semanticColors = AppSemanticColors.of(context);

    return Row(
      children: [
        Icon(
          Icons.celebration_outlined,
          size: AppSpacing.iconSize,
          color: semanticColors.holiday,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: semanticColors.holiday,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityLine extends StatelessWidget {
  const _ActivityLine({required this.activity});

  final AgendaActivity activity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = AppSemanticColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            activity.isDone
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            size: AppSpacing.iconSize - 4,
            color: activity.isDone
                ? semanticColors.brandDeep
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              activity.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                decoration: activity.isDone ? TextDecoration.lineThrough : null,
                color: activity.isDone
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurface,
              ),
            ),
          ),
          if (activity.startTime != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              activity.startTime!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
