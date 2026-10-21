import 'package:flutter/material.dart';

/// Cartão que cresce suavemente quando o ponteiro passa por cima, deixando
/// claro que o conteúdo está ativo. Em tela de toque nada muda: o toque vai
/// direto para o conteúdo.
class AppHoverCard extends StatefulWidget {
  const AppHoverCard({super.key, required this.child, this.scale = 1.05});

  final Widget child;

  /// Quanto o cartão cresce no hover. O padrão dá destaque sem cobrir o
  /// cartão vizinho.
  final double scale;

  @override
  State<AppHoverCard> createState() => _AppHoverCardState();
}

class _AppHoverCardState extends State<AppHoverCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) {
      return;
    }
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1,
        alignment: Alignment.center,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
