/// Tempos de espera e animação usados no lugar de valores soltos.
abstract final class AppDurations {
  /// Espera do ponteiro sobre um item antes de mostrar as informações dele
  /// (nome no menu, resumo no dia, detalhe no nó do grafo).
  static const Duration hoverTooltip = Duration(seconds: 1);
}
