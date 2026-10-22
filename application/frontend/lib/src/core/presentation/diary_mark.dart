import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

/// Marca do Modern Diary: um diário aberto com fita marcadora.
///
/// Desenha sobre o símbolo do [AppLogo], que entrega o gradiente da marca:
/// aqui ficam o brilho, as páginas e a fita. Tudo é vetor, então a marca fica
/// nítida do favicon ao cabeçalho.
class DiaryMark extends StatelessWidget {
  const DiaryMark({super.key});

  /// Dourado da fita: cor de apoio da marca, fora da paleta do tema.
  static const Color _ribbon = Color(0xFFF5C95B);

  @override
  Widget build(BuildContext context) {
    final colors = AppSemanticColors.of(context);
    return SizedBox.expand(
      child: CustomPaint(
        painter: _DiaryMarkPainter(
          detailColor: colors.brandDeep,
          ribbonColor: _ribbon,
        ),
      ),
    );
  }
}

class _DiaryMarkPainter extends CustomPainter {
  const _DiaryMarkPainter({
    required this.detailColor,
    required this.ribbonColor,
  });

  final Color detailColor;
  final Color ribbonColor;

  /// O desenho é feito em um quadrado de 100 x 100 e escalado para o tamanho
  /// real do símbolo.
  static const double _viewBox = 100;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox, size.height / _viewBox);
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _viewBox, _viewBox),
        const Radius.circular(_viewBox * 0.32),
      ),
    );

    _paintGloss(canvas);
    _paintBook(canvas);
    _paintEdge(canvas);

    canvas.restore();
  }

  /// Brilho no canto superior esquerdo: separa a marca do fundo chapado.
  void _paintGloss(Canvas canvas) {
    const bounds = Rect.fromLTWH(0, 0, _viewBox, _viewBox);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.center,
          colors: [Color(0x24FFFFFF), Color(0x00FFFFFF)],
        ).createShader(bounds),
    );
  }

  void _paintBook(Canvas canvas) {
    final book = Path()
      ..moveTo(49.5, 34)
      ..cubicTo(41.5, 28, 30, 27, 21, 30)
      ..lineTo(21, 71)
      ..cubicTo(30, 68, 41.5, 69, 49.5, 75)
      ..cubicTo(57.5, 69, 69, 68, 78, 71)
      ..lineTo(78, 30)
      ..cubicTo(69, 27, 57.5, 28, 49.5, 34)
      ..close();

    canvas.drawPath(
      book.shift(const Offset(0, 2.5)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(book, Paint()..color = Colors.white);

    // Lombada: divide as duas páginas.
    canvas.drawLine(
      const Offset(49.5, 34),
      const Offset(49.5, 75),
      Paint()
        ..color = detailColor
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // Fita marcadora da página da direita.
    final ribbon = Path()
      ..moveTo(58, 31.5)
      ..lineTo(58, 45.5)
      ..lineTo(63, 41.9)
      ..lineTo(68, 45.5)
      ..lineTo(68, 31.5)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = ribbonColor);

    final lines = Paint()
      ..color = detailColor.withValues(alpha: 0.42)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final line in const [
      [Offset(30, 45), Offset(41, 45)],
      [Offset(30, 52.5), Offset(41, 52.5)],
      [Offset(59, 45), Offset(70, 45)],
      [Offset(59, 52.5), Offset(70, 52.5)],
    ]) {
      canvas.drawLine(line[0], line[1], lines);
    }
  }

  /// Fio claro na borda: dá o acabamento de peça, não de ícone.
  void _paintEdge(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1.2, 1.2, _viewBox - 2.4, _viewBox - 2.4),
        const Radius.circular(_viewBox * 0.3),
      ),
      Paint()
        ..color = const Color(0x2EFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(_DiaryMarkPainter oldDelegate) {
    return oldDelegate.detailColor != detailColor ||
        oldDelegate.ribbonColor != ribbonColor;
  }
}
