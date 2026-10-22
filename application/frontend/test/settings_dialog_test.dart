import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/preferences/app_preferences.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/agenda/data/holidays_repository.dart';
import 'package:modern_diary/src/features/settings/data/countries_repository.dart';
import 'package:modern_diary/src/features/settings/domain/country_models.dart';
import 'package:modern_diary/src/features/settings/presentation/settings_dialog.dart';
import 'package:atena_ui/atena_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHolidays implements HolidaysDataSource {
  String? country;
  int calls = 0;

  @override
  Future<HolidaySyncResult> sync(String countryIso2) async {
    calls += 1;
    country = countryIso2;
    return const HolidaySyncResult(total: 4, years: [2026, 2027]);
  }
}

class _FakeCountries implements CountriesDataSource {
  final List<String?> queries = [];

  @override
  Future<CountryPage> fetchPage({
    required int page,
    int? perPage,
    String? query,
  }) async {
    queries.add(query);
    final countries = query == null || query.isEmpty
        ? const [
            Country(
              id: 1,
              iso2: 'BR',
              iso3: 'BRA',
              name: 'Brasil',
              flagEmoji: '🇧🇷',
              phoneCode: '+55',
            ),
            Country(
              id: 2,
              iso2: 'PT',
              iso3: 'PRT',
              name: 'Portugal',
              flagEmoji: '🇵🇹',
              phoneCode: '+351',
            ),
          ]
        : const [
            Country(
              id: 2,
              iso2: 'PT',
              iso3: 'PRT',
              name: 'Portugal',
              flagEmoji: '🇵🇹',
              phoneCode: '+351',
            ),
          ];
    return CountryPage(
      countries: countries,
      page: 1,
      perPage: perPage ?? 12,
      total: countries.length,
      totalPages: 1,
    );
  }
}

Future<void> _openSettings(
  WidgetTester tester,
  AppPreferences preferences, {
  CountriesDataSource? countries,
  HolidaysDataSource? holidays,
  ToatController? toat,
  VoidCallback? onHolidaysSynced,
  void Function(SettingsDraft? draft)? onClosed,
}) async {
  final toatController = toat ?? ToatController();
  addTearDown(toatController.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final draft = await showSettingsDialog(
                context,
                preferences: preferences,
                countries: countries ?? _FakeCountries(),
                holidays: holidays ?? _FakeHolidays(),
                toat: toatController,
                onHolidaysSynced: onHolidaysSynced,
              );
              onClosed?.call(draft);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('escolher o tema escuro e salvar devolve o ajuste', (
    tester,
  ) async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    SettingsDraft? draft;

    await _openSettings(
      tester,
      preferences,
      onClosed: (value) => draft = value,
    );

    expect(find.text(AppStrings.settingsTitle), findsOneWidget);
    expect(find.text(AppStrings.settingsThemeLight), findsOneWidget);

    await tester.tap(find.text(AppStrings.settingsThemeDark));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.settingsLocationLabel),
      'Recife',
    );
    await tester.ensureVisible(find.text(AppStrings.settingsSave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.settingsSave));
    await tester.pumpAndSettle();

    expect(draft, isNotNull);
    expect(draft!.themeMode, ThemeMode.dark);
    expect(draft!.location, 'Recife');
    expect(draft!.nationalityIso2, isNull);
    expect(find.text(AppStrings.settingsTitle), findsNothing);
  });

  testWidgets('cancelar fecha sem devolver ajuste', (tester) async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    var closedWithDraft = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                final draft = await showSettingsDialog(
                  context,
                  preferences: preferences,
                  countries: _FakeCountries(),
                  holidays: _FakeHolidays(),
                  toat: ToatController(),
                );
                closedWithDraft = draft != null;
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.cancel));
    await tester.pumpAndSettle();

    expect(closedWithDraft, isFalse);
  });

  testWidgets('escolher a nacionalidade devolve o país no ajuste', (
    tester,
  ) async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    final countries = _FakeCountries();
    SettingsDraft? draft;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                draft = await showSettingsDialog(
                  context,
                  preferences: preferences,
                  countries: countries,
                  holidays: _FakeHolidays(),
                  toat: ToatController(),
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsNationalityHint), findsOneWidget);

    await tester.tap(find.text(AppStrings.settingsNationalityHint));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.countryPickerTitle), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.countrySearchLabel),
      'portugal',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.settingsNationalityHint), findsNothing);
    expect(find.text('Portugal'), findsOneWidget);

    await tester.ensureVisible(find.text(AppStrings.settingsSave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.settingsSave));
    await tester.pumpAndSettle();

    expect(draft?.nationalityIso2, 'PT');
    expect(draft?.nationalityName, 'Portugal');
    expect(countries.queries.last, 'portugal');
  });

  testWidgets('a nacionalidade salva aparece nos ajustes', (tester) async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    await preferences.save(nationalityIso2: 'BR', nationalityName: 'Brasil');

    await _openSettings(tester, preferences);

    expect(find.text('Brasil'), findsOneWidget);
    expect(find.byTooltip(AppStrings.settingsNationalityClear), findsOneWidget);
  });

  testWidgets('puxar feriados usa a nacionalidade salva', (tester) async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    await preferences.save(nationalityIso2: 'BR', nationalityName: 'Brasil');
    final holidays = _FakeHolidays();
    var synced = false;

    await _openSettings(
      tester,
      preferences,
      holidays: holidays,
      onHolidaysSynced: () => synced = true,
    );

    await tester.ensureVisible(find.text(AppStrings.holidaySyncButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.holidaySyncButton));
    await tester.pumpAndSettle();

    expect(holidays.calls, 1);
    expect(holidays.country, 'BR');
    expect(synced, isTrue);

    await tester.pump(ToatController.autoDismissDuration);
    await tester.pumpAndSettle();
  });

  testWidgets('sem nacionalidade, puxar feriados pede para escolher uma', (
    tester,
  ) async {
    final preferences = AppPreferences();
    addTearDown(preferences.dispose);
    final holidays = _FakeHolidays();

    await _openSettings(tester, preferences, holidays: holidays);

    await tester.ensureVisible(find.text(AppStrings.holidaySyncButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.holidaySyncButton));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.countryPickerTitle), findsOneWidget);
    expect(holidays.calls, 0);

    await tester.tap(find.text('Brasil'));
    await tester.pumpAndSettle();

    expect(holidays.calls, 1);
    expect(holidays.country, 'BR');

    await tester.pump(ToatController.autoDismissDuration);
    await tester.pumpAndSettle();
  });
}
