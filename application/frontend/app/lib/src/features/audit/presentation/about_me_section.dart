import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/user.dart';
import '../../home/presentation/home_navigation.dart';
import '../data/audit_repository.dart';
import 'audit_controller.dart';
import 'audit_day_view.dart';

/// Sobre mim: os dados da conta e a auditoria, com o grafo de cada dia.
class AboutMeSection extends StatefulWidget {
  const AboutMeSection({
    super.key,
    required this.repository,
    required this.user,
    this.navigation,
  });

  final AuditDataSource repository;
  final User user;
  final HomeNavigation? navigation;

  @override
  State<AboutMeSection> createState() => _AboutMeSectionState();
}

class _AboutMeSectionState extends State<AboutMeSection> {
  late final AuditController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AuditController(widget.repository)..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppStrings.aboutMeTitle, style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.aboutMeSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurface(
            child: Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                _ProfileFact(
                  icon: Icons.person_outline_rounded,
                  label: AppStrings.aboutMeUsername,
                  value: widget.user.username,
                ),
                _ProfileFact(
                  icon: Icons.verified_user_outlined,
                  label: AppStrings.aboutMeRoleLabel,
                  value: AppStrings.roleLabel(widget.user.role.apiValue),
                ),
                _ProfileFact(
                  icon: Icons.event_available_outlined,
                  label: AppStrings.aboutMeMemberSince,
                  value: AppStrings.shortDate(widget.user.createdAt.toLocal()),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.auditTitle, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.auditSubtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppSurface(child: _monthCalendar(context)),
          const SizedBox(height: AppSpacing.lg),
          AuditDayView(controller: _controller, navigation: widget.navigation),
        ],
      ),
    );
  }

  Widget _monthCalendar(BuildContext context) {
    final month = _controller.month;
    final marks = _controller.daysOfMonth;

    return Row(
      children: [
        IconButton(
          tooltip: AppStrings.previousMonth,
          onPressed: () => _controller.moveMonth(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: MonthCalendar(
            year: month.year,
            month: month.month,
            monthName: AppStrings.monthName(month.month),
            weekdayLabels: AppStrings.weekdayShort,
            marks: {
              for (final entry in marks.entries)
                entry.key: CalendarDayMark(
                  activitiesTotal: entry.value.total,
                  activitiesDone: entry.value.total,
                ),
            },
            selectedDay: _controller.selectedDay,
            today: _controller.today,
            onDaySelected: (day) =>
                _controller.selectDay(DateTime(month.year, month.month, day)),
            daySemanticLabel: (day, mark) =>
                AppStrings.auditDaySemantics(day, mark.activitiesTotal),
          ),
        ),
        IconButton(
          tooltip: AppStrings.nextMonth,
          onPressed: () => _controller.moveMonth(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Dado da conta no cartão de perfil.
class _ProfileFact extends StatelessWidget {
  const _ProfileFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSpacing.lg, color: semanticColors.brandDeep),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
