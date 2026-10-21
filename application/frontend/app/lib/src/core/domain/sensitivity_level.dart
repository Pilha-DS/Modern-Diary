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

/// Áreas do sistema que recebem permissões independentes por credencial.
enum PermissionArea {
  conhecimentos('conhecimentos'),
  notas('notas'),
  metas('metas'),
  dias('dias'),
  atividades('atividades');

  const PermissionArea(this.apiValue);

  final String apiValue;

  /// Área desconhecida é ignorada em vez de derrubar a leitura da credencial.
  static PermissionArea? tryFromApi(String? value) {
    for (final area in values) {
      if (area.apiValue == value) {
        return area;
      }
    }
    return null;
  }
}
