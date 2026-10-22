import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_durations.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Item do menu orbital, exibido ao redor da bola central.
class OrbitalMenuItem {
  const OrbitalMenuItem({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.isSelected = false,
    this.isCentered = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool isSelected;

  /// Fica alinhado ao centro do arco, logo acima da bola.
  final bool isCentered;
}

/// Bola central de navegação. Abre os itens em órbita ao passar o mouse,
/// tocar ou focar. Funciona igual em telas de toque.
///
/// Os itens são só ícones, próximos uns dos outros; o nome aparece no tooltip
/// depois de [tooltipWait]. Cada item usa a superfície invertida do tema para
/// saltar do fundo.
class OrbitalMenu extends StatefulWidget {
  const OrbitalMenu({
    super.key,
    required this.items,
    required this.semanticLabel,
    this.tooltipWait = AppDurations.hoverTooltip,
  });

  final List<OrbitalMenuItem> items;
  final String semanticLabel;

  /// Tempo de hover para o nome do item aparecer.
  final Duration tooltipWait;

  @override
  State<OrbitalMenu> createState() => _OrbitalMenuState();
}

class _OrbitalMenuState extends State<OrbitalMenu>
    with SingleTickerProviderStateMixin {
  static const double _ballSize = 56;
  static const double _minMenuHeight = 190;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  static const Duration _closeDelay = Duration(milliseconds: 480);
  bool _isOpen = false;
  DateTime? _openedByHoverAt;
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _open({bool byHover = false}) {
    _closeTimer?.cancel();
    if (_isOpen) {
      return;
    }
    if (byHover) {
      _openedByHoverAt = DateTime.now();
    }
    setState(() => _isOpen = true);
    _controller.forward();
  }

  void _close() {
    _closeTimer?.cancel();
    if (!_isOpen) {
      return;
    }
    _controller.reverse().whenComplete(() {
      if (mounted && _controller.status == AnimationStatus.dismissed) {
        setState(() => _isOpen = false);
      }
    });
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(_closeDelay, _close);
  }

  void _toggle() {
    if (_isOpen) {
      final openedByHover = _openedByHoverAt;
      if (openedByHover != null &&
          DateTime.now().difference(openedByHover) <
              const Duration(milliseconds: 600)) {
        return;
      }
      _close();
      return;
    }
    _open();
  }

  void _select(OrbitalMenuItem item) {
    _close();
    item.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 520.0;
        final layout = _OrbitalLayout.forItems(
          widget.items.length,
          availableWidth,
          centerIndex: widget.items.indexWhere((item) => item.isCentered),
        );
        final width = layout.width;
        final menuHeight = math.max(_minMenuHeight, layout.radius + 68);
        final center = Offset(width / 2, menuHeight - _ballSize / 2 - 2);

        final menu = Stack(
          clipBehavior: Clip.none,
          children: [
            if (_isOpen)
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final value = _progress.value;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var index = 0; index < widget.items.length; index++)
                        _buildItem(context, index, center, layout, value),
                    ],
                  );
                },
              ),
            Positioned(
              left: center.dx - _ballSize / 2,
              top: center.dy - _ballSize / 2,
              child: MouseRegion(
                onEnter: (_) {
                  _closeTimer?.cancel();
                  _open(byHover: true);
                },
                onExit: (_) => _scheduleClose(),
                child: Semantics(
                  button: true,
                  label: widget.semanticLabel,
                  onTap: _toggle,
                  excludeSemantics: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggle,
                    child: _Ball(isOpen: _isOpen),
                  ),
                ),
              ),
            ),
          ],
        );

        final framed = SizedBox(width: width, height: menuHeight, child: menu);

        if (!_isOpen) {
          return framed;
        }

        return MouseRegion(
          onEnter: (_) => _closeTimer?.cancel(),
          onExit: (_) => _scheduleClose(),
          child: framed,
        );
      },
    );
  }

  Widget _buildItem(
    BuildContext context,
    int index,
    Offset center,
    _OrbitalLayout layout,
    double value,
  ) {
    final item = widget.items[index];
    final count = widget.items.length;
    final itemWidth = layout.itemWidth;
    final radians = layout.angleFor(index, count) * math.pi / 180;
    final itemRadius = layout.radiusOf(index);
    final target = Offset(
      center.dx + itemRadius * math.cos(radians),
      center.dy - itemRadius * math.sin(radians),
    );
    final left = center.dx - itemWidth / 2 + (target.dx - center.dx) * value;
    final top = center.dy - itemWidth / 2 + (target.dy - center.dy) * value;

    return Positioned(
      left: left.clamp(0, layout.width - itemWidth),
      top: top,
      width: itemWidth,
      height: itemWidth,
      child: MouseRegion(
        onEnter: (_) => _closeTimer?.cancel(),
        onExit: (_) => _scheduleClose(),
        child: IgnorePointer(
          ignoring: value < 0.95,
          child: Opacity(
            opacity: value.clamp(0, 1),
            child: Transform.scale(
              scale: 0.7 + 0.3 * value,
              child: _OrbitalItemButton(
                item: item,
                tooltipWait: widget.tooltipWait,
                onTap: () => _select(item),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Distribui os itens em arco e abre o raio conforme a quantidade: com mais
/// itens, o círculo cresce para um alvo não cobrir o outro. Quando um item é
/// central, ele fica sozinho no topo e os demais se dividem à esquerda e à
/// direita, garantindo o centro livre para o botão de início.
class _OrbitalLayout {
  const _OrbitalLayout({
    required this.width,
    required this.itemWidth,
    required this.radius,
    required this.centerIndex,
    required this.innerRadius,
  });

  final double width;
  final double itemWidth;
  final double radius;
  final int centerIndex;
  final double innerRadius;

  static const double _minRadius = 84;
  // 320 acomoda o menu cheio (12 itens) sem um alvo cobrir o outro; em tela
  // estreita o `fitRadius` continua mandando.
  static const double _maxRadius = 320;
  static const double _centerGapDegrees = 26;

  factory _OrbitalLayout.forItems(
    int count,
    double availableWidth, {
    int centerIndex = -1,
  }) {
    final maxWidth = availableWidth.isFinite ? availableWidth : 520.0;
    var itemWidth = 48.0;
    var required = _requiredRadius(count, itemWidth, centerIndex);
    var fitRadius = (maxWidth - itemWidth) / 2 - 4;

    if (required > fitRadius) {
      itemWidth = 44;
      required = _requiredRadius(count, itemWidth, centerIndex);
      fitRadius = (maxWidth - itemWidth) / 2 - 4;
    }

    final limit = math.max(fitRadius, 64.0);
    final radius = required
        .clamp(math.min(_minRadius, limit), math.min(_maxRadius, limit))
        .toDouble();
    final width = math.min(maxWidth, math.max(300.0, radius * 2 + itemWidth));

    return _OrbitalLayout(
      width: width,
      itemWidth: itemWidth,
      radius: radius,
      centerIndex: centerIndex,
      innerRadius: math.max(60, radius * 0.46),
    );
  }

  static double _requiredRadius(int count, double itemWidth, int centerIndex) {
    if (centerIndex < 0) {
      if (count < 2) {
        return _minRadius;
      }
      final step = 160 / (count - 1);
      return (itemWidth + 8) / (2 * math.sin(step * math.pi / 360));
    }

    final others = count - 1;
    final leftCount = (others + 1) ~/ 2;
    final rightCount = others - leftCount;
    final maxSide = math.max(leftCount, rightCount);
    if (maxSide < 2) {
      return _minRadius;
    }
    final step = (80 - _centerGapDegrees) / (maxSide - 1);
    return (itemWidth + 8) / (2 * math.sin(step * math.pi / 360));
  }

  double radiusOf(int index) => index == centerIndex ? innerRadius : radius;

  double angleFor(int index, int count) {
    if (centerIndex < 0) {
      return count == 1 ? 90 : 170 - 160 * index / (count - 1);
    }
    if (index == centerIndex) {
      return 90;
    }

    final others = count - 1;
    final leftCount = (others + 1) ~/ 2;
    final position = index < centerIndex ? index : index - 1;
    if (position < leftCount) {
      if (leftCount == 1) {
        return 143;
      }
      return 170 - (80 - _centerGapDegrees) * position / (leftCount - 1);
    }

    final rightCount = others - leftCount;
    final rightPosition = position - leftCount;
    if (rightCount == 1) {
      return 37;
    }
    return (90 - _centerGapDegrees) -
        (80 - _centerGapDegrees) * rightPosition / (rightCount - 1);
  }
}

class _Ball extends StatefulWidget {
  const _Ball({required this.isOpen});
  final bool isOpen;

  @override
  State<_Ball> createState() => _BallState();
}

class _BallState extends State<_Ball> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final semanticColors = AppSemanticColors.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.06 : 1,
        duration: const Duration(milliseconds: 160),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [semanticColors.brand, semanticColors.brandDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: semanticColors.brand.withValues(alpha: 0.32),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedRotation(
            turns: widget.isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.isOpen ? Icons.close_rounded : Icons.hub_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitalItemButton extends StatefulWidget {
  const _OrbitalItemButton({
    required this.item,
    required this.tooltipWait,
    required this.onTap,
  });

  final OrbitalMenuItem item;
  final Duration tooltipWait;
  final VoidCallback onTap;

  /// Círculo do item; o alvo de toque é a célula de [_OrbitalLayout.itemWidth].
  static const double _circleSize = 40;

  @override
  State<_OrbitalItemButton> createState() => _OrbitalItemButtonState();
}

class _OrbitalItemButtonState extends State<_OrbitalItemButton> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final semanticColors = AppSemanticColors.of(context);
    // Fundo invertido em relação ao tema: no claro fica escuro e vice-versa,
    // o que destaca o menu de navegação do resto da tela.
    final background = item.isSelected
        ? semanticColors.brand
        : semanticColors.contrastSurface;
    final foreground = item.isSelected
        ? Theme.of(context).colorScheme.onTertiary
        : semanticColors.contrastInk;
    // No hover o item cresce e ganha um halo da própria cor: é o sinal de
    // que aquele ícone é um botão.
    final haloColor = (item.isSelected ? semanticColors.brand : background)
        .withValues(alpha: _hovered ? 0.5 : 0.0);

    return Tooltip(
      message: item.label,
      waitDuration: widget.tooltipWait,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: item.isSelected,
        label: item.label,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => _setHovered(true),
          onExit: (_) => _setHovered(false),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: Center(
              child: AnimatedScale(
                scale: _hovered ? 1.12 : 1,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _OrbitalItemButton._circleSize,
                  height: _OrbitalItemButton._circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: background,
                    boxShadow: [
                      BoxShadow(
                        color: semanticColors.shadow,
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                      if (_hovered)
                        BoxShadow(
                          color: haloColor,
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Icon(
                    item.icon,
                    size: AppSpacing.iconSize,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
