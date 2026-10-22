import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/settings/data/countries_repository.dart';
import 'package:modern_diary/src/features/settings/domain/country_models.dart';
import 'package:modern_diary/src/features/settings/presentation/country_picker.dart';
import 'package:atena_ui/atena_ui.dart';

class _StubCountries implements CountriesDataSource {
  _StubCountries(this._respond);

  final Future<CountryPage> Function(int page, String? query) _respond;
  final List<String?> queries = [];

  @override
  Future<CountryPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
  }) {
    queries.add(query);
    return _respond(page, query);
  }
}

CountryPage _page(
  List<Country> countries, {
  required int page,
  int totalPages = 1,
}) {
  return CountryPage(
    countries: countries,
    page: page,
    perPage: 12,
    total: countries.length,
    totalPages: totalPages,
  );
}

const _brazil = Country(
  id: 1,
  iso2: 'BR',
  iso3: 'BRA',
  name: 'Brasil',
  flagEmoji: '🇧🇷',
  phoneCode: '+55',
  continent: 'América do Sul',
);

const _portugal = Country(
  id: 2,
  iso2: 'PT',
  iso3: 'PRT',
  name: 'Portugal',
  flagEmoji: '🇵🇹',
  phoneCode: '+351',
  continent: 'Europa',
);

Future<void> _openPicker(
  WidgetTester tester,
  CountriesDataSource dataSource, {
  String? selectedIso2,
  void Function(Country?)? onPicked,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final country = await showCountryPicker(
                context,
                dataSource: dataSource,
                selectedIso2: selectedIso2,
              );
              onPicked?.call(country);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
}

void main() {
  testWidgets('lista países e devolve o escolhido', (tester) async {
    Country? picked;
    await _openPicker(
      tester,
      _StubCountries((page, query) async => _page(const [_brazil], page: 1)),
      onPicked: (country) => picked = country,
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.countryPickerTitle), findsOneWidget);
    expect(find.text('Brasil'), findsOneWidget);

    await tester.tap(find.text('Brasil'));
    await tester.pumpAndSettle();

    expect(picked?.iso2, 'BR');
    expect(find.text(AppStrings.countryPickerTitle), findsNothing);
  });

  testWidgets('carrega a próxima página sob demanda', (tester) async {
    final stub = _StubCountries(
      (page, query) async => page == 1
          ? _page(const [_brazil], page: 1, totalPages: 2)
          : _page(const [_portugal], page: 2, totalPages: 2),
    );
    await _openPicker(tester, stub);
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsNothing);

    await tester.tap(find.text(AppStrings.countriesLoadMore));
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text(AppStrings.countriesLoadMore), findsNothing);
    expect(stub.queries, hasLength(2));
  });

  testWidgets('busca com debounce envia o termo digitado', (tester) async {
    final stub = _StubCountries(
      (page, query) async => query == 'brasil'
          ? _page(const [_brazil], page: 1)
          : _page(const [], page: 1),
    );
    await _openPicker(tester, stub);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.countriesEmptyTitle), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.countrySearchLabel),
      'brasil',
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Antes do debounce nada foi pedido.
    expect(stub.queries, hasLength(1));

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(stub.queries.last, 'brasil');
    expect(find.text('Brasil'), findsOneWidget);
  });

  testWidgets('erro mostra a mensagem e permite tentar de novo', (
    tester,
  ) async {
    var failed = false;
    final stub = _StubCountries((page, query) async {
      if (!failed) {
        failed = true;
        throw const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Sem conexão.',
        );
      }
      return _page(const [_brazil], page: 1);
    });
    await _openPicker(tester, stub);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.countriesErrorTitle), findsOneWidget);
    expect(find.text('Sem conexão.'), findsOneWidget);

    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();

    expect(find.text('Brasil'), findsOneWidget);
  });

  testWidgets('mostra a seleção atual', (tester) async {
    await _openPicker(
      tester,
      _StubCountries(
        (page, query) async => _page(const [_brazil, _portugal], page: 1),
      ),
      selectedIso2: 'PT',
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    // A bandeira é derivada do ISO2 quando o back não manda o emoji.
    expect(countryFlagEmoji('pt'), '🇵🇹');
  });
}
