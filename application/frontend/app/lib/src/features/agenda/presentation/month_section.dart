import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import 'agenda_controller.dart';
import 'calendar_marks.dart';
import 'day_preview.dart';

/// Cartão do mês com os dias marcados, cobrindo carregando, vazio e erro.
class MonthSection extends StatelessWidget {
  const MonthSection({
    super.key,
    required this.controller,
    required this.month,
    this.onDayOpen,
    this.hint,
  });

  final AgendaController controller;
  final DateTime month;

  /// Abre o dia escolhido em outra área. Sem ele, clicar no dia só o seleciona.
  final ValueChanged<DateTime>? onDayOpen;

  /// Texto abaixo do calendário explicando como abrir o dia.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final isLoaded = controller.isYearLoadedFor(month.year);
    final isLoading =
        controller.isLoadingYear && controller.year == month.year && !isLoaded;
    final error = controller.year == month.year ? controller.yearError : null;
    final isCurrentMonth =
        month.year == controller.today.year &&
        month.month == controller.today.month;

    return AppSurface(
      shadowColor: isCurrentMonth
          ? AppSemanticColors.of(context).highlightShadow
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const StatusView.loading(title: AppStrings.agendaLoadingMonth)
          else if (error != null && !isLoaded)
            StatusView.error(
              title: AppStrings.agendaMonthErrorTitle,
              message: error.message,
              actionLabel: AppStrings.retry,
              onAction: () => controller.loadYear(month.year, force: true),
            )
          else ...[
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: InlineMessage(
                  message: error.message,
                  variant: InlineMessageVariant.error,
                ),
              ),
            MonthCalendar(
              year: month.year,
              month: month.month,
              monthName: AppStrings.monthName(month.month),
              weekdayLabels: AppStrings.weekdayShort,
              marks: marksForMonth(
                controller.summariesForYear(month.year),
                month.year,
                month.month,
              ),
              selectedDay: controller.selectedDay,
              today: controller.today,
              daySemanticLabel: daySemanticLabel,
              dayPreview: (context, day, mark) =>
                  AgendaDayPreview(controller: controller, day: day),
              onDaySelected: (dayNumber) {
                final day = DateTime(month.year, month.month, dayNumber);
                controller.selectDay(day);
                onDayOpen?.call(day);
              },
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                hint!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
