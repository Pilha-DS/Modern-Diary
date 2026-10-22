/// Informações de quem fez o projeto, mostradas no rodapé.
///
/// Tudo é fixo em build: dá para trocar por `--dart-define` (ou pelas `args` do
/// Docker Compose), sem mexer no código.
/// ```
/// flutter run --dart-define=APP_AUTHOR_NAME=Jonathan \
///   --dart-define=APP_CONTACT_EMAIL=eu@exemplo.com
/// ```
/// Valor vazio cai no padrão, e campo opcional vazio não aparece no rodapé.
abstract final class AppInfo {
  static const String _authorName = String.fromEnvironment('APP_AUTHOR_NAME');
  static const String _authorContact = String.fromEnvironment(
    'APP_CONTACT_EMAIL',
  );
  static const String _authorPhone = String.fromEnvironment('APP_AUTHOR_PHONE');
  static const String _authorSite = String.fromEnvironment('APP_AUTHOR_SITE');
  static const String _version = String.fromEnvironment('APP_VERSION');

  static String get authorName => _or(_authorName, 'Jonathan Cardoso');
  static String get authorContact =>
      _or(_authorContact, 'jonathan.cardoso2212@gmail.com');
  static String get authorPhone => _authorPhone.trim();
  static String get authorSite => _authorSite.trim();
  static String get version => _or(_version, '1.0.0');

  static String _or(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value.trim();
}
