import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fundo padrão do projeto: base clara com ondas suaves na cor de identidade.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colorScheme.surface, colorScheme.surfaceContainerHighest],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WavesPainter(color: semanticColors.brand),
              ),
            ),
          ),
          // O gradiente é pintado acima do `Material` do `Scaffold`: sem esta
          // camada transparente, o hover e o toque dos botões ficariam
          // escondidos atrás do fundo e nenhum item pareceria clicável.
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

class _WavesPainter extends CustomPainter {
  const _WavesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final firstWave = Path()
      ..moveTo(-size.width * 0.1, size.height * 0.20)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.08,
        size.width * 0.55,
        size.height * 0.17,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.26,
        size.width * 1.1,
        size.height * 0.12,
      );
    canvas.drawPath(firstWave, paint);

    final secondWave = Path()
      ..moveTo(-size.width * 0.1, size.height * 0.26)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.14,
        size.width * 0.65,
        size.height * 0.23,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.31,
        size.width * 1.1,
        size.height * 0.19,
      );
    canvas.drawPath(secondWave, paint);
  }

  @override
  bool shouldRepaint(covariant _WavesPainter oldDelegate) =>
      oldDelegate.color != color;
}
