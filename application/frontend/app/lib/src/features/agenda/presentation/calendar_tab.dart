import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../../tags/data/tags_repository.dart';
import 'agenda_controller.dart';
import 'calendar_marks.dart';
import 'day_panel_dialog.dart';
import 'day_preview.dart';

/// Visão anual: os doze meses crescem ao passar o mouse e cada dia abre o
/// dia em um modal. O mês grande fica só no dashboard.
class CalendarTab extends StatefulWidget {
  const CalendarTab({
    super.key,
    required this.controller,
    required this.tagsDataSource,
    required this.toat,
    this.navigation,
    this.focusDay,
    this.onFocusHandled,
  });

  final AgendaController controller;
  final TagsDataSource tagsDataSource;
  final ToatController toat;

  /// Leva a tag clicada no dia até o menu de tags.
  final HomeNavigation? navigation;

  /// Dia que outra área pediu para abrir; o pedido é consumido ao abrir.
  final DateTime? focusDay;
  final VoidCallback? onFocusHandled;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  AgendaController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
  }

  @override
  void didUpdateWidget(CalendarTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusDay != oldWidget.focusDay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
    }
  }

  void _handleFocus() {
    final day = widget.focusDay;
    if (day == null || !mounted) {
      return;
    }
    widget.onFocusHandled?.call();
    _focusDay(day);
  }

  Future<void> _focusDay(DateTime day) async {
    if (controller.year != day.year) {
      await controller.loadYear(day.year);
    }
    if (!mounted) {
      return;
    }
    _openDay(context, day);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  void _openDay(BuildContext context, DateTime day) {
    showDayPanelDialog(
      context,
      controller: controller,
      tagsDataSource: widget.tagsDataSource,
      toat: widget.toat,
      day: day,
      navigation: widget.navigation,
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isLoaded = controller.isYearLoaded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: AppStrings.previousYear,
                  onPressed: controller.isLoadingYear
                      ? null
                      : () => controller.loadYear(controller.year - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Semantics(
                  header: true,
                  label: AppStrings.calendarYearSemantics('${controller.year}'),
                  excludeSemantics: true,
                  child: Text(
                    '${controller.year}',
                    style: textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: AppStrings.nextYear,
                  onPressed: controller.isLoadingYear
                      ? null
                      : () => controller.loadYear(controller.year + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            AppButton(
              label: AppStrings.todayButton,
              icon: Icons.today_rounded,
              variant: AppButtonVariant.ghost,
              onPressed: controller.goToToday,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (controller.isLoadingYear && !isLoaded)
          const StatusView.loading(title: AppStrings.agendaLoadingMonth)
        else if (controller.yearError != null && !isLoaded)
          StatusView.error(
            title: AppStrings.agendaYearErrorTitle,
            message: controller.yearError!.message,
            actionLabel: AppStrings.retry,
            onAction: () => controller.loadYear(controller.year, force: true),
          )
        else ...[
          if (controller.yearError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InlineMessage(
                message: controller.yearError!.message,
                variant: InlineMessageVariant.error,
              ),
            ),
          Text(
            AppStrings.monthsOfYear(controller.year),
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _YearGrid(
            controller: controller,
            onDaySelected: (day) => _openDay(context, day),
          ),
        ],
      ],
    );
  }
}

class _YearGrid extends StatelessWidget {
  const _YearGrid({required this.controller, required this.onDaySelected});

  final AgendaController controller;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final summaries = controller.summariesForYear(controller.year);
    final highlightShadow = AppSemanticColors.of(context).highlightShadow;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Três meses por linha; em telas estreitas cai para duas ou uma.
        final columns = switch (constraints.maxWidth) {
          >= 720 => 3,
          >= 480 => 2,
          _ => 1,
        };
        const spacing = AppSpacing.md;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        Widget monthCard(int month) {
          final isCurrentMonth =
              controller.year == controller.today.year &&
              month == controller.today.month;

          return SizedBox(
            width: cardWidth,
            child: AppHoverCard(
              child: AppSurface(
                padding: const EdgeInsets.all(AppSpacing.lg),
                shadowColor: isCurrentMonth ? highlightShadow : null,
                child: MonthCalendar(
                  compact: true,
                  year: controller.year,
                  month: month,
                  monthName: AppStrings.monthName(month),
                  weekdayLabels: AppStrings.weekdayShort,
                  marks: marksForMonth(summaries, controller.year, month),
                  selectedDay: controller.selectedDay,
                  today: controller.today,
                  isHighlighted: isCurrentMonth,
                  daySemanticLabel: daySemanticLabel,
                  dayPreview: (context, day, mark) =>
                      AgendaDayPreview(controller: controller, day: day),
                  onDaySelected: (dayNumber) => onDaySelected(
                    DateTime(controller.year, month, dayNumber),
                  ),
                ),
              ),
            ),
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var month = 1; month <= 12; month++) monthCard(month),
          ],
        );
      },
    );
  }
}
