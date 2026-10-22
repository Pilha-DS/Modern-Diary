import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'core/network/auth_token.dart';
import 'core/preferences/app_preferences.dart';
import 'core/strings/app_strings.dart';
import 'features/agenda/data/agenda_repository.dart';
import 'features/agenda/data/holidays_repository.dart';
import 'features/audit/data/audit_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/session_store.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/goals/data/goals_repository.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/knowledge/data/knowledge_repository.dart';
import 'features/life/data/life_repository.dart';
import 'features/notes/data/notes_repository.dart';
import 'features/search/data/search_repository.dart';
import 'features/secrets/data/secrets_repository.dart';
import 'features/settings/data/countries_repository.dart';
import 'features/tags/data/tags_repository.dart';
import 'features/users/data/users_repository.dart';

class ModernDiaryApp extends StatefulWidget {
  const ModernDiaryApp({super.key});

  @override
  State<ModernDiaryApp> createState() => _ModernDiaryAppState();
}

class _ModernDiaryAppState extends State<ModernDiaryApp> {
  late final AuthToken _token;
  late final ApiClient _apiClient;
  late final AuthController _authController;
  late final UsersRepository _usersRepository;
  late final AgendaRepository _agendaRepository;
  late final HolidaysRepository _holidaysRepository;
  late final GoalsRepository _goalsRepository;
  late final KnowledgeRepository _knowledgeRepository;
  late final LifeRepository _lifeRepository;
  late final NotesRepository _notesRepository;
  late final SearchRepository _searchRepository;
  late final TagsRepository _tagsRepository;
  late final AuditRepository _auditRepository;
  late final SecretsRepository _secretsRepository;
  late final CountriesRepository _countriesRepository;
  late final ToatController _toatController;
  late final AppPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _token = AuthToken();
    _apiClient = ApiClient(
      baseUrl: ApiConfig.baseUrl,
      tokenProvider: () => _token.value,
    );
    _usersRepository = UsersRepository(_apiClient);
    _agendaRepository = AgendaRepository(_apiClient);
    _holidaysRepository = HolidaysRepository(_apiClient);
    _goalsRepository = GoalsRepository(_apiClient);
    _knowledgeRepository = KnowledgeRepository(_apiClient);
    _lifeRepository = LifeRepository(_apiClient);
    _notesRepository = NotesRepository(_apiClient);
    _searchRepository = SearchRepository(_apiClient);
    _tagsRepository = TagsRepository(_apiClient);
    _auditRepository = AuditRepository(_apiClient);
    _secretsRepository = SecretsRepository(_apiClient);
    _countriesRepository = CountriesRepository(_apiClient);
    _toatController = ToatController();
    _preferences = AppPreferences()..load();
    _authController = AuthController(
      repository: AuthRepository(_apiClient),
      store: SessionStore(),
      token: _token,
    );
    _authController.restoreSession();
  }

  @override
  void dispose() {
    _authController.dispose();
    _toatController.dispose();
    _preferences.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _preferences,
      builder: (context, _) {
        return MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _preferences.themeMode,
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return ToatHost(
              controller: _toatController,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: ListenableBuilder(
            listenable: _authController,
            builder: (context, _) {
              return switch (_authController.status) {
                AuthStatus.checking => const _SplashScreen(),
                AuthStatus.unauthenticated => AuthScreen(
                  controller: _authController,
                  toat: _toatController,
                ),
                AuthStatus.authenticated => HomeScreen(
                  auth: _authController,
                  toat: _toatController,
                  preferences: _preferences,
                  usersRepository: _usersRepository,
                  agendaRepository: _agendaRepository,
                  holidaysRepository: _holidaysRepository,
                  goalsRepository: _goalsRepository,
                  knowledgeRepository: _knowledgeRepository,
                  lifeRepository: _lifeRepository,
                  notesRepository: _notesRepository,
                  searchRepository: _searchRepository,
                  tagsRepository: _tagsRepository,
                  auditRepository: _auditRepository,
                  secretsRepository: _secretsRepository,
                  countriesRepository: _countriesRepository,
                ),
              };
            },
          ),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogo(
                size: AppSpacing.xxl,
                semanticLabel: AppStrings.appName,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.appName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              const SizedBox.square(
                dimension: AppSpacing.lg,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.sessionLoading,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
