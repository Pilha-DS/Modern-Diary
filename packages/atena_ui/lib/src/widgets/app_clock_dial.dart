import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Relógio de escolha: os valores ficam em órbita, um por posição, e o centro
/// mostra o valor escolhido.
///
/// Serve tanto para horas (24 posições) quanto para minutos (60 posições).
/// Quando há muitas posições, [labelEvery] mostra o número só de tempos em
/// tempos (os minutos a cada 5) e o restante fica como marca; todas as
/// posições continuam selecionáveis, pelo toque, pelo arrasto do mouse (hover)
/// e pelas setas do teclado.
///
/// ```dart
/// AppClockDial(
///   count: 24,
///   value: hour,
///   labelEvery: 1,
///   semanticLabel: 'Hora',
///   onChanged: (value) => setState(() => hour = value),
/// )
/// ```
class AppClockDial extends StatefulWidget {
  const AppClockDial({
    super.key,
    required this.count,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.labelEvery = 1,
    this.maxSize = 260,
  }) : assert(count > 1),
       assert(labelEvery > 0);

  /// Quantidade de posições da órbita: 24 para horas, 60 para minutos.
  final int count;

  /// Posição escolhida, de 0 até [count] - 1.
  final int value;

  final ValueChanged<int> onChanged;

  /// Rótulo lido pelo leitor de tela ("Hora", "Minuto").
  final String semanticLabel;

  /// Mostra o número a cada N posições; as demais viram marca.
  final int labelEvery;

  /// Tamanho máximo do relógio; ele encolhe para caber no espaço disponível.
  final double maxSize;

  /// Folga entre a borda e a órbita, onde ficam os números.
  static const double _edgeInset = 20;

  @override
  State<AppClockDial> createState() => _AppClockDialState();
}

class _AppClockDialState extends State<AppClockDial> {
  final FocusNode _focusNode = FocusNode();
  int? _hovered;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Posição mais próxima do ponteiro, pelo ângulo em relação ao centro.
  /// Toque perto do centro é ignorado: ali fica o valor escolhido.
  int? _indexAt(Offset position, Size size, double radius) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = position - center;
    if (delta.distance < radius * 0.45) {
      return null;
    }
    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) {
      angle += 2 * math.pi;
    }
    final step = 2 * math.pi / widget.count;
    return (angle / step).round() % widget.count;
  }

  void _selectAt(Offset position, Size size, double radius) {
    final index = _indexAt(position, size, radius);
    if (index != null && index != widget.value) {
      widget.onChanged(index);
    }
  }

  void _step(int delta) {
    final next = (widget.value + delta) % widget.count;
    widget.onChanged(next < 0 ? next + widget.count : next);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowUp:
        _step(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowDown:
        _step(-1);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  String _label(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : widget.maxSize;
        final size = math.min(widget.maxSize, available);
        final radius = size / 2 - AppClockDial._edgeInset;
        final fontSize = (size / 21).clamp(10.0, 13.0);

        return Semantics(
          label: widget.semanticLabel,
          value: _label(widget.value),
          increasedValue: _label((widget.value + 1) % widget.count),
          decreasedValue: _label(
            (widget.value - 1 + widget.count) % widget.count,
          ),
          onIncrease: () => _step(1),
          onDecrease: () => _step(-1),
          child: Focus(
            focusNode: _focusNode,
            onFocusChange: (value) => setState(() => _focused = value),
            onKeyEvent: _handleKey,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (event) {
                final index = _indexAt(
                  event.localPosition,
                  Size.square(size),
                  radius,
                );
                if (index != _hovered) {
                  setState(() => _hovered = index);
                }
              },
              onExit: (_) {
                if (_hovered != null) {
                  setState(() => _hovered = null);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) {
                  _focusNode.requestFocus();
                  _selectAt(details.localPosition, Size.square(size), radius);
                },
                child: SizedBox.square(
                  dimension: size,
                  child: CustomPaint(
                    painter: _ClockDialPainter(
                      count: widget.count,
                      value: widget.value,
                      hovered: _hovered,
                      focused: _focused,
                      labelEvery: widget.labelEvery,
                      radius: radius,
                      labelStyle: theme.textTheme.bodySmall!.copyWith(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                      ),
                      centerStyle: theme.textTheme.headlineSmall!.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      colorScheme: theme.colorScheme,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClockDialPainter extends CustomPainter {
  const _ClockDialPainter({
    required this.count,
    required this.value,
    required this.hovered,
    required this.focused,
    required this.labelEvery,
    required this.radius,
    required this.labelStyle,
    required this.centerStyle,
    required this.colorScheme,
  });

  final int count;
  final int value;
  final int? hovered;
  final bool focused;
  final int labelEvery;
  final double radius;
  final TextStyle labelStyle;
  final TextStyle centerStyle;
  final ColorScheme colorScheme;

  static const double _markerRadius = 13;

  Offset _positionOf(int index, Size size) {
    final angle = -math.pi / 2 + 2 * math.pi * index / count;
    return Offset(
      size.width / 2 + radius * math.cos(angle),
      size.height / 2 + radius * math.sin(angle),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = focused ? 1.6 : 1
      ..color = focused
          ? colorScheme.primary.withValues(alpha: 0.6)
          : colorScheme.outlineVariant.withValues(alpha: 0.5);

    canvas.drawCircle(center, radius + _markerRadius + 3, guidePaint);
    canvas.drawCircle(center, radius - _markerRadius - 3, guidePaint);

    // Ponteiro até a posição escolhida, para o relógio ser lido de relance.
    final selectedPosition = _positionOf(value, size);
    final direction = selectedPosition - center;
    final distance = direction.distance;
    if (distance > 0) {
      final unit = direction / distance;
      canvas.drawLine(
        center + unit * (radius * 0.55),
        center + unit * (radius - _markerRadius - 4),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = colorScheme.primary.withValues(alpha: 0.35),
      );
    }

    for (var index = 0; index < count; index++) {
      final position = _positionOf(index, size);
      final isSelected = index == value;
      final isHovered = index == hovered;
      final isLabeled = index % labelEvery == 0;

      if (isSelected || isHovered) {
        canvas.drawCircle(
          position,
          _markerRadius,
          Paint()
            ..color = isSelected
                ? colorScheme.primary
                : colorScheme.primary.withValues(alpha: 0.14),
        );
      }

      if (isLabeled) {
        _paintCenteredText(
          canvas,
          position,
          index.toString().padLeft(2, '0'),
          labelStyle.copyWith(
            color: isSelected
                ? colorScheme.onPrimary
                : isHovered
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        );
        continue;
      }

      canvas.drawCircle(
        position,
        isSelected ? 4 : (isHovered ? 3.5 : 2),
        Paint()
          ..color = isSelected
              ? colorScheme.onPrimary
              : isHovered
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
      );
    }

    _paintCenteredText(
      canvas,
      center,
      value.toString().padLeft(2, '0'),
      centerStyle,
    );
  }

  void _paintCenteredText(
    Canvas canvas,
    Offset center,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _ClockDialPainter oldDelegate) {
    return oldDelegate.count != count ||
        oldDelegate.value != value ||
        oldDelegate.hovered != hovered ||
        oldDelegate.focused != focused ||
        oldDelegate.labelEvery != labelEvery ||
        oldDelegate.radius != radius ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.centerStyle != centerStyle ||
        oldDelegate.colorScheme != colorScheme;
  }
}
