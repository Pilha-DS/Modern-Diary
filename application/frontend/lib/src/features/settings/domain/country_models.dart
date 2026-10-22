/// País da tabela de referência do back (ISO 3166-1).
class Country {
  const Country({
    required this.id,
    required this.iso2,
    required this.iso3,
    required this.name,
    required this.flagEmoji,
    this.longName,
    this.phoneCode,
    this.continent,
  });

  final int id;
  final String iso2;
  final String iso3;
  final String name;
  final String flagEmoji;
  final String? longName;
  final String? phoneCode;
  final String? continent;

  factory Country.fromJson(Map<String, dynamic> json) {
    final iso2 = json['iso2'] as String? ?? '';
    final flag = json['flag_emoji'] as String? ?? '';
    return Country(
      id: json['id'] as int? ?? 0,
      iso2: iso2,
      iso3: json['iso3'] as String? ?? '',
      name: json['name'] as String? ?? '',
      flagEmoji: flag.isEmpty ? countryFlagEmoji(iso2) : flag,
      longName: json['long_name'] as String?,
      phoneCode: json['phone_code'] as String?,
      continent: json['continent'] as String?,
    );
  }

  /// Complemento curto exibido ao lado do nome, como "América do Sul · +55".
  String get subtitle {
    return [
      if (phoneCode != null && phoneCode!.isNotEmpty) phoneCode!,
      if (continent != null && continent!.isNotEmpty) continent!,
      iso2,
    ].join(' · ');
  }
}

class CountryPage {
  const CountryPage({
    required this.countries,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<Country> countries;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Bandeira em emoji a partir do código ISO de duas letras.
///
/// Mesma regra do back: cada letra vira o indicador regional correspondente,
/// então o ajuste salvo no dispositivo mostra a bandeira sem nova consulta.
String countryFlagEmoji(String iso2) {
  final code = iso2.trim().toUpperCase();
  if (code.length != 2) {
    return '';
  }
  return String.fromCharCodes(
    code.codeUnits.map((unit) => 0x1F1E6 + unit - 0x41),
  );
}
