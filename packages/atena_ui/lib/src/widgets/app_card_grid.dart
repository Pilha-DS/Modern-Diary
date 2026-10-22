import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Grade responsiva de cartões com **altura uniforme por linha**.
///
/// Cálculo da coluna fica aqui, não em cada tela: todos os cartões da mesma
/// linha recebem a mesma largura e a mesma altura da linha, e as linhas seguem
/// se o cartão não couber na largura disponível.
///
/// A altura igual sai do [IntrinsicHeight]: a linha mede o cartão mais alto e
/// estica os demais até ele. Por isso o cartão deve preencher a altura
/// recebida (por exemplo, com uma `Column` e um `Spacer` antes do rodapé).
///
/// ```dart
/// AppCardGrid(
///   minCardWidth: 220,
///   maxColumns: 4,
///   children: [for (final item in items) ItemCard(item: item)],
/// )
/// ```
class AppCardGrid extends StatelessWidget {
  const AppCardGrid({
    super.key,
    required this.children,
    this.minCardWidth = 240,
    this.maxColumns = 4,
    this.spacing = AppSpacing.md,
  }) : assert(minCardWidth > 0),
       assert(maxColumns > 0);

  final List<Widget> children;

  /// Largura mínima para uma coluna; abaixo disso o cartão ocupa a linha toda.
  final double minCardWidth;

  /// Teto de colunas, mesmo que caibam mais na largura disponível.
  final int maxColumns;

  /// Espaço entre colunas e entre linhas.
  final double spacing;

  /// Quantas colunas cabem em [availableWidth] com a largura mínima.
  int columnsFor(double availableWidth) {
    if (!availableWidth.isFinite || availableWidth <= 0) {
      return 1;
    }
    final fitted = ((availableWidth + spacing) / (minCardWidth + spacing))
        .floor();
    return fitted.clamp(1, maxColumns);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(constraints.maxWidth);
        final rows = <Widget>[];

        for (var start = 0; start < children.length; start += columns) {
          if (rows.isNotEmpty) {
            rows.add(SizedBox(height: spacing));
          }
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) SizedBox(width: spacing),
                    Expanded(
                      child: column + start < children.length
                          ? children[start + column]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        );
      },
    );
  }
}
