/// Áreas cobertas pela pesquisa universal.
enum SearchType {
  knowledge('knowledge'),
  goal('goal'),
  note('note'),
  agendaNote('agenda_note'),
  activity('activity');

  const SearchType(this.apiValue);

  final String apiValue;

  static SearchType? fromApi(String value) {
    for (final type in values) {
      if (type.apiValue == value) {
        return type;
      }
    }
    return null;
  }
}

/// Um registro encontrado, já com a prévia do conteúdo.
class SearchResult {
  const SearchResult({
    required this.type,
    required this.ref,
    required this.sensitivity,
    this.title,
    this.snippet,
    this.day,
    this.updatedAt,
  });

  final SearchType type;
  final String ref;
  final String sensitivity;
  final String? title;
  final String? snippet;
  final DateTime? day;
  final DateTime? updatedAt;

  int? get numericRef => int.tryParse(ref);

  static SearchResult? fromJson(Map<String, dynamic> json) {
    final type = SearchType.fromApi(json['type'] as String? ?? '');
    final ref = json['ref'] as String?;
    if (type == null || ref == null) {
      return null;
    }
    final snippet = (json['snippet'] as String?)?.trim();
    return SearchResult(
      type: type,
      ref: ref,
      sensitivity: json['sensitivity'] as String? ?? 'publico',
      title: json['title'] as String?,
      snippet: snippet == null || snippet.isEmpty ? null : snippet,
      day: _parseDate(json['day']),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}

/// Página de resultados, com a paginação que veio no `meta`.
class SearchPage {
  const SearchPage({
    this.results = const [],
    this.page = 1,
    this.total = 0,
    this.totalPages = 0,
  });

  final List<SearchResult> results;
  final int page;
  final int total;
  final int totalPages;
}
