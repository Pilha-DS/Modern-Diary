/// Hierarquia de sensibilidade de um dado e limite de leitura de uma
/// credencial. A ordem declara a hierarquia: um limite libera o próprio nível
/// e todos os anteriores.
///
/// `all` só existe como limite de leitura; nenhum registro é gravado com ele.
enum SensitivityLevel {
  publico('publico'),
  basico('basico'),
  moderado('moderado'),
  complexo('complexo'),
  sigiloso('sigiloso'),
  all('all');

  const SensitivityLevel(this.apiValue);

  /// Valor usado pela API.
  final String apiValue;

  /// Níveis aceitos em um registro. `all` é só limite de permissão.
  static const List<SensitivityLevel> dataLevels = [
    publico,
    basico,
    moderado,
    complexo,
    sigiloso,
  ];

  static SensitivityLevel fromApi(
    String? value, {
    SensitivityLevel fallback = publico,
  }) {
    for (final level in values) {
      if (level.apiValue == value) {
        return level;
      }
    }
    return fallback;
  }
}
