/// Endereço da API. Pode ser trocado em build/run:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8000`
abstract final class ApiConfig {
  static const String rawBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static String get baseUrl {
    final trimmed = rawBaseUrl.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
