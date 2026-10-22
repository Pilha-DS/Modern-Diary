/// Níveis de sensibilidade vêm do `atena_ui`, que é o mesmo em todo o ecossistema.
/// Aqui fica só o que é do domínio do Modern Diary: as áreas que recebem
/// permissões independentes por credencial.
library;

export 'package:atena_ui/atena_ui.dart' show SensitivityLevel;

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
