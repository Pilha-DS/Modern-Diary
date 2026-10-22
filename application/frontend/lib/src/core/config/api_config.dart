/// Endereço da API. Pode ser trocado em build/run:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8470`
///
/// O padrão é a porta publicada pelo `docker compose` (`API_PORT` no `.env`).
/// Portas de uso comum do ecossistema (8000, 8080, 3306) ficam de fora de
/// propósito: elas costumam estar ocupadas por outros serviços da máquina.
abstract final class ApiConfig {
  static const String rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8470',
  );

  static String get baseUrl {
    final trimmed = rawBaseUrl.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
