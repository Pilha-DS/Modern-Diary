import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_durations.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Prioridade visual de um dia no calendário.
enum CalendarPriority { none, low, medium, high }

/// Marcas de um dia: nota, atividades, feriado e a maior prioridade entre elas.
@immutable
class CalendarDayMark {
  const CalendarDayMark({
    this.hasNote = false,
    this.activitiesTotal = 0,
    this.activitiesDone = 0,
    this.priority = CalendarPriority.none,
    this.holiday,
  });

  final bool hasNote;
  final int activitiesTotal;
  final int activitiesDone;
  final CalendarPriority priority;

  /// Nome do feriado; o status do dia vem antes das marcas de conteúdo.
  final String? holiday;

  bool get hasActivities => activitiesTotal > 0;
  bool get hasHoliday => holiday != null;
  bool get isEmpty => !hasNote && !hasActivities && !hasHoliday;
}

/// Calendário de um mês, sem bordas e com o dia marcado por cor de fundo.
///
/// Em [compact] mostra só a prévia do mês (sem toque por dia), usada na visão
/// anual. A localização vem de fora: [monthName] e [weekdayLabels]. Dia com
/// conteúdo abre uma prévia ao lado da célula depois de [AppDurations.hoverTooltip]
/// de hover, montada por [dayPreview].
///
/// Uso com prévia:
///
/// ```dart
/// MonthCalendar(
///   year: 2026,
///   month: 10,
///   monthName: 'Outubro',
///   weekdayLabels: const ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'],
///   marks: {21: const CalendarDayMark(activitiesTotal: 2)},
///   dayPreview: (context, day, mark) => Text('$day — ${mark.activitiesTotal} atividades'),
/// )
/// ```
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.monthName,
    required this.weekdayLabels,
    this.marks = const {},
    this.selectedDay,
    this.today,
    this.onDaySelected,
    this.onTap,
    this.compact = false,
    this.isHighlighted = false,
    this.daySemanticLabel,
    this.dayPreview,
    this.cardSemanticLabel,
  }) : assert(weekdayLabels.length == 7);

  final int year;
  final int month;
  final String monthName;
  final List<String> weekdayLabels;
  final Map<int, CalendarDayMark> marks;
  final DateTime? selectedDay;
  final DateTime? today;
  final ValueChanged<int>? onDaySelected;
  final VoidCallback? onTap;
  final bool compact;
  final bool isHighlighted;
  final String Function(DateTime day, CalendarDayMark mark)? daySemanticLabel;

  /// Conteúdo da prévia do dia, exibida ao lado da célula no hover.
  final Widget Function(
    BuildContext context,
    DateTime day,
    CalendarDayMark mark,
  )?
  dayPreview;
  final String? cardSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final firstWeekday = DateTime(year, month, 1).weekday % 7;
    final totalDays = DateUtils.getDaysInMonth(year, month);

    final cells = <Widget>[
      for (var blank = 0; blank < firstWeekday; blank++) _emptyCell(),
      for (var day = 1; day <= totalDays; day++)
        Expanded(child: _dayCell(context, day)),
    ];
    // No modo compacto todos os meses ocupam as seis semanas possíveis, para
    // que meses com 4 ou 5 semanas não fiquem com altura diferente no ano.
    final totalRows = compact ? 6 : (cells.length / 7).ceil();
    while (cells.length < totalRows * 7) {
      cells.add(_emptyCell());
    }

    final weeks = <Widget>[
      for (var index = 0; index < cells.length; index += 7)
        Row(children: cells.sublist(index, index + 7)),
    ];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              month.toString().padLeft(2, '0'),
              style: textTheme.bodySmall?.copyWith(
                color: isHighlighted
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                monthName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (compact ? textTheme.titleSmall : textTheme.titleMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isHighlighted
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
              ),
            ),
            if (!compact)
              Text(
                '$year',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (compact)
              Icon(
                Icons.chevron_right_rounded,
                size: AppSpacing.iconSize,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
        SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
        Row(
          children: [
            for (final label in weekdayLabels)
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: compact ? 9 : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 2 : AppSpacing.xs),
        ...weeks,
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Semantics(
      container: true,
      button: true,
      label: cardSemanticLabel ?? monthName,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: content,
      ),
    );
  }

  /// Célula vazia com a mesma proporção de um dia, para que a semana não
  /// encolha quando não tem número.
  Widget _emptyCell() {
    return const Expanded(
      child: AspectRatio(aspectRatio: 1, child: SizedBox.shrink()),
    );
  }

  Widget _dayCell(BuildContext context, int dayNumber) {
    final day = DateTime(year, month, dayNumber);
    final mark = marks[dayNumber] ?? const CalendarDayMark();
    final isToday = today != null && DateUtils.isSameDay(day, today);
    final isSelected =
        selectedDay != null && DateUtils.isSameDay(day, selectedDay);

    final label =
        daySemanticLabel?.call(day, mark) ?? '$dayNumber/$month/$year';
    final preview = dayPreview;
    final previewBuilder = preview == null || mark.isEmpty
        ? null
        : (BuildContext previewContext) => preview(previewContext, day, mark);

    return _CalendarDayCell(
      dayNumber: dayNumber,
      mark: mark,
      isToday: isToday,
      isSelected: isSelected,
      compact: compact,
      label: label,
      onTap: onDaySelected == null ? null : () => onDaySelected!(dayNumber),
      previewBuilder: previewBuilder,
    );
  }
}

/// Célula de um dia. Guarda o hover para dar o apoio visual em cinza-claro.
///
/// Cada estado tem a sua cor: hoje fica verde, a seleção fica azul sólida e as
/// marcas do dia (feriado, prioridade alta, nota e atividade) usam fundos suaves
/// próprios, para um dia com conteúdo nunca se confundir com o dia selecionado.
class _CalendarDayCell extends StatefulWidget {
  const _CalendarDayCell({
    required this.dayNumber,
    required this.mark,
    required this.isToday,
    required this.isSelected,
    required this.compact,
    required this.label,
    required this.onTap,
    this.previewBuilder,
  });

  final int dayNumber;
  final CalendarDayMark mark;
  final bool isToday;
  final bool isSelected;
  final bool compact;
  final String label;
  final VoidCallback? onTap;
  final WidgetBuilder? previewBuilder;

  @override
  State<_CalendarDayCell> createState() => _CalendarDayCellState();
}

class _CalendarDayCellState extends State<_CalendarDayCell> {
  bool _hovered = false;
  bool _openPreviewToLeft = false;
  double _previewVerticalAnchor = 0;
  Timer? _previewTimer;
  final OverlayPortalController _previewController = OverlayPortalController();
  final LayerLink _previewLink = LayerLink();

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    if (widget.previewBuilder == null) {
      return;
    }
    _previewTimer = Timer(AppDurations.hoverTooltip, _showPreview);
  }

  void _showPreview() {
    if (!mounted || !_hovered || widget.previewBuilder == null) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final screenSize = MediaQuery.sizeOf(context);
      final center = box.localToGlobal(box.size.center(Offset.zero));
      setState(() {
        _openPreviewToLeft =
            center.dx >
            screenSize.width - AppSpacing.hoverPreviewWidth - AppSpacing.md;
        // O painel cresce para baixo no topo da tela, para cima no rodapé e
        // centralizado no meio, sempre encostado na célula.
        _previewVerticalAnchor = center.dy < screenSize.height * 0.3
            ? -1.0
            : center.dy > screenSize.height * 0.7
            ? 1.0
            : 0.0;
      });
    }
    _previewController.show();
  }

  void _hidePreview() {
    _previewTimer?.cancel();
    _previewTimer = null;
    if (_previewController.isShowing) {
      _previewController.hide();
    }
  }

  (Color, Color) _colors(
    ColorScheme colorScheme,
    AppSemanticColors semanticColors,
  ) {
    // Hoje vem antes da seleção: o dia atual nunca perde o verde.
    if (widget.isToday) {
      return (semanticColors.brandSoft, semanticColors.brandDeep);
    }
    // A seleção é azul sólida: nenhuma marca do dia usa essa combinação, então
    // o dia aberto nunca se confunde com um dia que só tem nota ou atividade.
    if (widget.isSelected) {
      return (colorScheme.primary, colorScheme.onPrimary);
    }
    // Feriado é um status do dia e vem antes das marcas de conteúdo.
    if (widget.mark.hasHoliday) {
      return (semanticColors.holidaySoft, semanticColors.holiday);
    }
    if (widget.mark.priority == CalendarPriority.high) {
      return (semanticColors.warningSoft, semanticColors.warning);
    }
    if (widget.mark.hasNote) {
      return (colorScheme.primaryContainer, colorScheme.primary);
    }
    if (widget.mark.hasActivities) {
      return (semanticColors.brandSoft, semanticColors.brandDeep);
    }
    if (_hovered) {
      return (colorScheme.secondaryContainer, colorScheme.onSurface);
    }
    return (Colors.transparent, colorScheme.onSurface);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);
    final (background, foreground) = _colors(colorScheme, semanticColors);

    // Hover em célula que já tem fundo vira anel, para a marca do dia não sumir.
    final wantsHoverRing =
        _hovered && background != Colors.transparent && !widget.isSelected;
    final border = switch ((
      widget.isSelected,
      widget.isToday,
      wantsHoverRing,
    )) {
      // Hoje selecionado continua verde: o anel azul mostra a seleção.
      (true, true, _) => Border.all(color: colorScheme.primary, width: 2),
      _ when wantsHoverRing => Border.all(
        color: colorScheme.primary.withValues(alpha: 0.55),
        width: 2,
      ),
      // Hoje fica verde, com anel da identidade para não se perder entre os dias.
      (_, true, _) => Border.all(
        color: semanticColors.brand.withValues(alpha: 0.55),
      ),
      _ => null,
    };

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      margin: EdgeInsets.all(widget.compact ? 1.5 : 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: border,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${widget.dayNumber}',
          style: (widget.compact ? textTheme.bodySmall : textTheme.bodyMedium)
              ?.copyWith(
                color: foreground,
                fontWeight:
                    widget.isSelected ||
                        widget.isToday ||
                        _hovered ||
                        !widget.mark.isEmpty
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: widget.compact ? 10 : null,
              ),
        ),
      ),
    );

    final cell = AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 1 : 3),
        child: chip,
      ),
    );

    final previewBuilder = widget.previewBuilder;
    final body = previewBuilder == null
        ? cell
        : OverlayPortal(
            controller: _previewController,
            overlayChildBuilder: (overlayContext) {
              final screenWidth = MediaQuery.sizeOf(overlayContext).width;
              final availableWidth = screenWidth - AppSpacing.md * 2;
              final previewWidth = availableWidth < AppSpacing.hoverPreviewWidth
                  ? availableWidth
                  : AppSpacing.hoverPreviewWidth;
              // O overlay mede o filho com as restrições rígidas da tela
              // inteira; o `Align` devolve a restrição frouxa para a prévia
              // ficar do tamanho dela, ancorada na célula pelo follower.
              final targetAnchor = Alignment(
                _openPreviewToLeft ? -1 : 1,
                _previewVerticalAnchor,
              );
              final followerAnchor = Alignment(
                _openPreviewToLeft ? 1 : -1,
                _previewVerticalAnchor,
              );
              return CompositedTransformFollower(
                link: _previewLink,
                showWhenUnlinked: false,
                targetAnchor: targetAnchor,
                followerAnchor: followerAnchor,
                offset: Offset(
                  _openPreviewToLeft ? -AppSpacing.sm : AppSpacing.sm,
                  0,
                ),
                child: Align(
                  alignment: followerAnchor,
                  child: IgnorePointer(
                    child: SizedBox(
                      width: previewWidth,
                      child: previewBuilder(overlayContext),
                    ),
                  ),
                ),
              );
            },
            child: CompositedTransformTarget(link: _previewLink, child: cell),
          );

    final hoverRegion = MouseRegion(
      onEnter: (_) {
        _setHovered(true);
        _schedulePreview();
      },
      onExit: (_) {
        _setHovered(false);
        _hidePreview();
      },
      child: body,
    );

    if (widget.onTap == null) {
      return Semantics(
        label: widget.label,
        selected: widget.isSelected,
        excludeSemantics: true,
        child: hoverRegion,
      );
    }

    return Semantics(
      button: true,
      label: widget.label,
      selected: widget.isSelected,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          _setHovered(true);
          _schedulePreview();
        },
        onExit: (_) {
          _setHovered(false);
          _hidePreview();
        },
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            _hidePreview();
            widget.onTap!();
          },
          onHighlightChanged: _setHovered,
          child: body,
        ),
      ),
    );
  }
}
