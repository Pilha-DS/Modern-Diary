import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'app_clock_dial.dart';
import 'app_dialog.dart';

/// Abre o relógio de escolha de horário: uma órbita de 24 horas e outra de 60
/// minutos. Devolve o horário confirmado ou `null` se o modal for fechado.
///
/// ```dart
/// final time = await showAppTimePicker(
///   context,
///   title: 'Escolher horário',
///   hoursLabel: 'Hora',
///   minutesLabel: 'Minuto',
///   cancelLabel: 'Cancelar',
///   confirmLabel: 'Confirmar',
///   closeLabel: 'Fechar',
///   initial: TimeOfDay.now(),
/// );
/// ```
Future<TimeOfDay?> showAppTimePicker(
  BuildContext context, {
  required String title,
  required String hoursLabel,
  required String minutesLabel,
  required String cancelLabel,
  required String confirmLabel,
  required String closeLabel,
  TimeOfDay? initial,
}) {
  final start = initial ?? TimeOfDay.now();

  return showAppDialog<TimeOfDay>(
    context,
    title: title,
    closeLabel: closeLabel,
    maxWidth: 560,
    child: _TimePickerBody(
      initial: start,
      hoursLabel: hoursLabel,
      minutesLabel: minutesLabel,
      cancelLabel: cancelLabel,
      confirmLabel: confirmLabel,
    ),
  );
}

class _TimePickerBody extends StatefulWidget {
  const _TimePickerBody({
    required this.initial,
    required this.hoursLabel,
    required this.minutesLabel,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final TimeOfDay initial;
  final String hoursLabel;
  final String minutesLabel;
  final String cancelLabel;
  final String confirmLabel;

  @override
  State<_TimePickerBody> createState() => _TimePickerBodyState();
}

class _TimePickerBodyState extends State<_TimePickerBody> {
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final hours = _dial(
              label: widget.hoursLabel,
              count: 24,
              labelEvery: 1,
              value: _hour,
              onChanged: (value) => setState(() => _hour = value),
            );
            final minutes = _dial(
              label: widget.minutesLabel,
              count: 60,
              labelEvery: 5,
              value: _minute,
              onChanged: (value) => setState(() => _minute = value),
            );

            // Lado a lado quando cabe; empilhado em tela estreita, sem cortar
            // nem sobrepor os dois relógios.
            if (constraints.maxWidth >= 420) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: hours),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: minutes),
                ],
              );
            }
            return Column(
              children: [
                hours,
                const SizedBox(height: AppSpacing.md),
                minutes,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(widget.cancelLabel),
            ),
            AppButton(
              label: widget.confirmLabel,
              icon: Icons.check_rounded,
              onPressed: () =>
                  Navigator.of(context)
                      .pop(TimeOfDay(hour: _hour, minute: _minute)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dial({
    required String label,
    required int count,
    required int labelEvery,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppClockDial(
          count: count,
          labelEvery: labelEvery,
          value: value,
          semanticLabel: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
