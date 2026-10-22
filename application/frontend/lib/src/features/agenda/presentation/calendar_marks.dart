import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/agenda_models.dart';
import 'activity_tile.dart';

CalendarDayMark markFromSummary(AgendaDaySummary? summary) {
  if (summary == null) {
    return const CalendarDayMark();
  }
  return CalendarDayMark(
    hasNote: summary.hasNote,
    activitiesTotal: summary.activitiesTotal,
    activitiesDone: summary.activitiesDone,
    holiday: summary.holiday,
    priority: switch (summary.highestPriority) {
      AgendaPriority.high => CalendarPriority.high,
      AgendaPriority.medium => CalendarPriority.medium,
      AgendaPriority.low => CalendarPriority.low,
      null => CalendarPriority.none,
    },
  );
}

Map<int, CalendarDayMark> marksForMonth(
  Map<String, AgendaDaySummary> summaries,
  int year,
  int month,
) {
  final marks = <int, CalendarDayMark>{};
  for (final summary in summaries.values) {
    if (summary.day.year == year && summary.day.month == month) {
      marks[summary.day.day] = markFromSummary(summary);
    }
  }
  return marks;
}

String daySemanticLabel(DateTime day, CalendarDayMark mark) {
  return AppStrings.daySemantics(
    day,
    hasNote: mark.hasNote,
    activities: mark.activitiesTotal,
    done: mark.activitiesDone,
    holiday: mark.holiday,
  );
}

ActivityPriority activityPriority(AgendaPriority priority) {
  return switch (priority) {
    AgendaPriority.high => ActivityPriority.high,
    AgendaPriority.medium => ActivityPriority.medium,
    AgendaPriority.low => ActivityPriority.low,
  };
}

String priorityLabel(AgendaPriority priority) {
  return switch (priority) {
    AgendaPriority.high => AppStrings.priorityHigh,
    AgendaPriority.medium => AppStrings.priorityMedium,
    AgendaPriority.low => AppStrings.priorityLow,
  };
}
