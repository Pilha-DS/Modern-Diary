import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/config/app_info.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../core/strings/app_strings.dart';
import '../../agenda/data/agenda_repository.dart';
import '../../agenda/data/holidays_repository.dart';
import '../../agenda/presentation/agenda_controller.dart';
import '../../agenda/presentation/calendar_tab.dart';
import '../../agenda/presentation/dashboard_tab.dart';
import '../../audit/data/audit_repository.dart';
import '../../audit/presentation/about_me_section.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/presentation/goals_section.dart';
import '../../knowledge/data/knowledge_repository.dart';
import '../../knowledge/presentation/knowledge_section.dart';
import '../../life/data/life_repository.dart';
import '../../life/presentation/life_graph_section.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/presentation/notes_section.dart';
import '../../search/data/search_repository.dart';
import '../../search/presentation/search_dialog.dart';
import '../../secrets/data/secrets_repository.dart';
import '../../secrets/presentation/secrets_section.dart';
import '../../settings/data/countries_repository.dart';
import '../../settings/presentation/settings_dialog.dart';
import '../../tags/data/tags_repository.dart';
import '../../tags/domain/tag_models.dart';
import '../../tags/presentation/tags_section.dart';
import '../../users/data/users_repository.dart';
import '../../users/presentation/users_section.dart';
import 'home_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.toat,
    required this.preferences,
    required this.usersRepository,
    required this.agendaRepository,
    required this.holidaysRepository,
    required this.goalsRepository,
    required this.knowledgeRepository,
    required this.lifeRepository,
    required this.notesRepository,
    required this.searchRepository,
    required this.tagsRepository,
    required this.auditRepository,
    required this.secretsRepository,
    required this.countriesRepository,
  });

  final AuthController auth;
  final ToatController toat;
  final AppPreferences preferences;
  final UsersRepository usersRepository;
  final AgendaRepository agendaRepository;
  final HolidaysDataSource holidaysRepository;
  final GoalsRepository goalsRepository;
  final KnowledgeRepository knowledgeRepository;
  final LifeDataSource lifeRepository;
  final NotesRepository notesRepository;
  final SearchDataSource searchRepository;
  final TagsRepository tagsRepository;
  final AuditRepository auditRepository;
  final SecretsRepository secretsRepository;
  final CountriesRepository countriesRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AgendaController _agenda;
  HomeSection _tab = HomeSection.dashboard;

  // Pedidos de navegação: a área de destino consome o pedido ao abrir.
  Tag? _pendingTag;
  int? _pendingGoalId;
  int? _pendingKnowledgeId;
  int? _pendingNoteId;
  DateTime? _pendingDay;

  late final HomeNavigation _navigation = HomeNavigation(
    openTag: (tag) => setState(() {
      _pendingTag = tag;
      _tab = HomeSection.tags;
    }),
    openGoal: (goalId) => setState(() {
      _pendingGoalId = goalId;
      _tab = HomeSection.goals;
    }),
    openKnowledgeItem: (itemId) => setState(() {
      _pendingKnowledgeId = itemId;
      _tab = HomeSection.knowledge;
    }),
    openNote: (noteId) => setState(() {
      _pendingNoteId = noteId;
      _tab = HomeSection.notes;
    }),
    openDay: (day) => setState(() {
      _pendingDay = day;
      _tab = HomeSection.calendar;
    }),
    openSection: (section) => setState(() => _tab = section),
  );

  void _consumeTagFocus() {
    if (_pendingTag != null) {
      setState(() => _pendingTag = null);
    }
  }

  void _consumeGoalFocus() {
    if (_pendingGoalId != null) {
      setState(() => _pendingGoalId = null);
    }
  }

  void _consumeKnowledgeFocus() {
    if (_pendingKnowledgeId != null) {
      setState(() => _pendingKnowledgeId = null);
    }
  }

  void _consumeNoteFocus() {
    if (_pendingNoteId != null) {
      setState(() => _pendingNoteId = null);
    }
  }

  void _consumeDayFocus() {
    if (_pendingDay != null) {
      setState(() => _pendingDay = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _agenda = AgendaController(widget.agendaRepository)..initialize();
  }

  @override
  void dispose() {
    _agenda.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    widget.toat.show(AppStrings.logoutSuccess, variant: ToatVariant.info);
  }

  /// Abre a pesquisa universal: header, menu orbital e tecla `Q`.
  Future<void> _openSearch() {
    return showSearchDialog(
      context,
      dataSource: widget.searchRepository,
      tagsDataSource: widget.tagsRepository,
      navigation: _navigation,
    );
  }

  /// `Q` é atalho de texto: só dispara quando nada está sendo digitado.
  KeyEventResult _handleSearchShortcut(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyQ) {
      return KeyEventResult.ignored;
    }
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus != null &&
        focus.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    _openSearch();
    return KeyEventResult.handled;
  }

  /// Abre as configurações básicas e aplica o que o usuário salvou.
  Future<void> _openSettings() async {
    final draft = await showSettingsDialog(
      context,
      preferences: widget.preferences,
      countries: widget.countriesRepository,
      holidays: widget.holidaysRepository,
      toat: widget.toat,
      onHolidaysSynced: () => _agenda.refresh(),
    );
    if (draft == null || !mounted) {
      return;
    }
    await widget.preferences.save(
      themeMode: draft.themeMode,
      location: draft.location,
      phone: draft.phone,
      nationalityIso2: draft.nationalityIso2,
      nationalityName: draft.nationalityName,
      clearNationality: draft.nationalityIso2 == null,
      avatarBytes: draft.avatarBytes,
      removeAvatar: draft.removeAvatar,
    );
    if (!mounted) {
      return;
    }
    widget.toat.show(AppStrings.settingsSaved, variant: ToatVariant.success);
  }

  List<OrbitalMenuItem> _menuItems({required bool isAdmin}) {
    return [
      OrbitalMenuItem(
        icon: Icons.home_outlined,
        label: AppStrings.dashboardTab,
        isSelected: _tab == HomeSection.dashboard,
        isCentered: true,
        onSelected: () => setState(() => _tab = HomeSection.dashboard),
      ),
      OrbitalMenuItem(
        icon: Icons.search_rounded,
        label: AppStrings.searchTitle,
        onSelected: _openSearch,
      ),
      OrbitalMenuItem(
        icon: Icons.calendar_month_outlined,
        label: AppStrings.calendarTab,
        isSelected: _tab == HomeSection.calendar,
        onSelected: () => setState(() => _tab = HomeSection.calendar),
      ),
      OrbitalMenuItem(
        icon: Icons.sticky_note_2_outlined,
        label: AppStrings.notesTab,
        isSelected: _tab == HomeSection.notes,
        onSelected: () => setState(() => _tab = HomeSection.notes),
      ),
      OrbitalMenuItem(
        icon: Icons.flag_outlined,
        label: AppStrings.goalsTab,
        isSelected: _tab == HomeSection.goals,
        onSelected: () => setState(() => _tab = HomeSection.goals),
      ),
      OrbitalMenuItem(
        icon: Icons.hub_outlined,
        label: AppStrings.knowledgeTab,
        isSelected: _tab == HomeSection.knowledge,
        onSelected: () => setState(() => _tab = HomeSection.knowledge),
      ),
      OrbitalMenuItem(
        icon: Icons.scatter_plot_outlined,
        label: AppStrings.liveGraphTab,
        isSelected: _tab == HomeSection.lifeGraph,
        onSelected: () => setState(() => _tab = HomeSection.lifeGraph),
      ),
      OrbitalMenuItem(
        icon: Icons.sell_outlined,
        label: AppStrings.tagsTab,
        isSelected: _tab == HomeSection.tags,
        onSelected: () => setState(() => _tab = HomeSection.tags),
      ),
      OrbitalMenuItem(
        icon: Icons.person_outline_rounded,
        label: AppStrings.aboutMeTab,
        isSelected: _tab == HomeSection.aboutMe,
        onSelected: () => setState(() => _tab = HomeSection.aboutMe),
      ),
      OrbitalMenuItem(
        icon: Icons.vpn_key_outlined,
        label: AppStrings.secretsTab,
        isSelected: _tab == HomeSection.secrets,
        onSelected: () => setState(() => _tab = HomeSection.secrets),
      ),
      if (isAdmin)
        OrbitalMenuItem(
          icon: Icons.people_outline_rounded,
          label: AppStrings.usersTitle,
          isSelected: _tab == HomeSection.users,
          onSelected: () => setState(() => _tab = HomeSection.users),
        ),
      OrbitalMenuItem(
        icon: Icons.tune_rounded,
        label: AppStrings.settingsShortLabel,
        onSelected: _openSettings,
      ),
      OrbitalMenuItem(
        icon: Icons.logout_rounded,
        label: AppStrings.logout,
        onSelected: _logout,
      ),
    ];
  }

  /// Telas da seleção rápida do dashboard, na mesma ordem do menu orbital.
  List<HomeQuickLink> _quickLinks({required bool isAdmin}) {
    return [
      const HomeQuickLink(
        section: HomeSection.calendar,
        icon: Icons.calendar_month_outlined,
        label: AppStrings.calendarTab,
      ),
      const HomeQuickLink(
        section: HomeSection.notes,
        icon: Icons.sticky_note_2_outlined,
        label: AppStrings.notesTab,
      ),
      const HomeQuickLink(
        section: HomeSection.goals,
        icon: Icons.flag_outlined,
        label: AppStrings.goalsTab,
      ),
      const HomeQuickLink(
        section: HomeSection.knowledge,
        icon: Icons.hub_outlined,
        label: AppStrings.knowledgeTab,
      ),
      const HomeQuickLink(
        section: HomeSection.lifeGraph,
        icon: Icons.scatter_plot_outlined,
        label: AppStrings.liveGraphTab,
      ),
      const HomeQuickLink(
        section: HomeSection.tags,
        icon: Icons.sell_outlined,
        label: AppStrings.tagsTab,
      ),
      const HomeQuickLink(
        section: HomeSection.aboutMe,
        icon: Icons.person_outline_rounded,
        label: AppStrings.aboutMeTab,
      ),
      const HomeQuickLink(
        section: HomeSection.secrets,
        icon: Icons.vpn_key_outlined,
        label: AppStrings.secretsTab,
      ),
      if (isAdmin)
        const HomeQuickLink(
          section: HomeSection.users,
          icon: Icons.people_outline_rounded,
          label: AppStrings.usersTitle,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Focus(
            autofocus: true,
            includeSemantics: false,
            onKeyEvent: _handleSearchShortcut,
            child: ListenableBuilder(
              listenable: Listenable.merge([widget.auth, widget.preferences]),
              builder: (context, _) {
                final user = widget.auth.user;
                if (user == null) {
                  return const SizedBox.shrink();
                }

                final tab = _tab == HomeSection.users && !user.isAdmin
                    ? HomeSection.dashboard
                    : _tab;

                // `StackFit.expand` prende o menu orbital ao rodapé da tela: sem
                // ele, a pilha encolhe até a altura do conteúdo e o menu sobe
                // junto com a página quando o conteúdo é curto.
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          120,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppSpacing.maxContentWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AppHeader(
                                  title: AppStrings.appName,
                                  subtitle: user.username,
                                  avatarLabel: user.username,
                                  avatarImage: widget.preferences.avatarImage,
                                  avatarTooltip: AppStrings.profileMenuLabel,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: AppStrings.searchAction,
                                        onPressed: _openSearch,
                                        icon: const Icon(Icons.search_rounded),
                                      ),
                                      RoleBadge(
                                        role: user.role.apiValue,
                                        label: AppStrings.roleLabel(
                                          user.role.apiValue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onLogoPressed: () => setState(
                                    () => _tab = HomeSection.dashboard,
                                  ),
                                  logoTooltip: AppStrings.logoHomeTooltip,
                                  menuItems: [
                                    AppHeaderMenuItem(
                                      icon: Icons.settings_outlined,
                                      label: AppStrings.settingsTitle,
                                      onSelected: _openSettings,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                // Toda tela ocupa pelo menos a altura
                                // visível: o rodapé nunca aparece no início
                                // da visão, só depois de rolar.
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.hasBoundedHeight
                                        ? constraints.maxHeight
                                        : 0,
                                  ),
                                  child: switch (tab) {
                                    HomeSection.dashboard => DashboardTab(
                                      controller: _agenda,
                                      username: user.username,
                                      quickLinks: _quickLinks(
                                        isAdmin: user.isAdmin,
                                      ),
                                      tagsDataSource: widget.tagsRepository,
                                      toat: widget.toat,
                                      navigation: _navigation,
                                    ),
                                    HomeSection.calendar => CalendarTab(
                                      controller: _agenda,
                                      tagsDataSource: widget.tagsRepository,
                                      toat: widget.toat,
                                      navigation: _navigation,
                                      focusDay: _pendingDay,
                                      onFocusHandled: _consumeDayFocus,
                                    ),
                                    HomeSection.notes => NotesSection(
                                      repository: widget.notesRepository,
                                      toat: widget.toat,
                                      focusNoteId: _pendingNoteId,
                                      onFocusHandled: _consumeNoteFocus,
                                    ),
                                    HomeSection.goals => GoalsSection(
                                      repository: widget.goalsRepository,
                                      tagsRepository: widget.tagsRepository,
                                      toat: widget.toat,
                                      navigation: _navigation,
                                      focusGoalId: _pendingGoalId,
                                      onFocusHandled: _consumeGoalFocus,
                                    ),
                                    HomeSection.knowledge => KnowledgeSection(
                                      repository: widget.knowledgeRepository,
                                      tagsRepository: widget.tagsRepository,
                                      goalsRepository: widget.goalsRepository,
                                      toat: widget.toat,
                                      navigation: _navigation,
                                      focusItemId: _pendingKnowledgeId,
                                      onFocusHandled: _consumeKnowledgeFocus,
                                    ),
                                    HomeSection.tags => TagsSection(
                                      repository: widget.tagsRepository,
                                      toat: widget.toat,
                                      navigation: _navigation,
                                      focusTag: _pendingTag,
                                      onFocusHandled: _consumeTagFocus,
                                    ),
                                    HomeSection.lifeGraph => LifeGraphSection(
                                      repository: widget.lifeRepository,
                                      toat: widget.toat,
                                      navigation: _navigation,
                                    ),
                                    HomeSection.aboutMe => AboutMeSection(
                                      repository: widget.auditRepository,
                                      user: user,
                                      navigation: _navigation,
                                    ),
                                    HomeSection.secrets => SecretsSection(
                                      repository: widget.secretsRepository,
                                      toat: widget.toat,
                                    ),
                                    HomeSection.users => UsersSection(
                                      repository: widget.usersRepository,
                                    ),
                                  },
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                const _AppFooter(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AppSpacing.md,
                      child: Center(
                        child: OrbitalMenu(
                          items: _menuItems(isAdmin: user.isAdmin),
                          semanticLabel: AppStrings.menuLabel,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Rodapé com os dados de quem fez o projeto, fixos em [AppInfo].
class _AppFooter extends StatelessWidget {
  const _AppFooter();

  @override
  Widget build(BuildContext context) {
    final contact = AppInfo.authorContact.trim();
    final phone = AppInfo.authorPhone.trim();
    final site = AppInfo.authorSite.trim();

    return AppFooter(
      appName: AppStrings.appName,
      tagline: AppStrings.appTagline,
      note: AppStrings.footerCreatedBy(AppInfo.authorName),
      items: [
        if (contact.isNotEmpty)
          AppFooterItem(
            icon: Icons.mail_outline_rounded,
            text: contact,
            semanticLabel: '${AppStrings.footerContactLabel}: $contact',
          ),
        if (phone.isNotEmpty)
          AppFooterItem(
            icon: Icons.call_outlined,
            text: phone,
            semanticLabel: '${AppStrings.footerPhoneLabel}: $phone',
          ),
        if (site.isNotEmpty)
          AppFooterItem(
            icon: Icons.public_rounded,
            text: site,
            semanticLabel: '${AppStrings.footerSiteLabel}: $site',
          ),
        AppFooterItem(
          icon: Icons.info_outline_rounded,
          text: AppStrings.footerVersion(AppInfo.version),
          semanticLabel: AppStrings.footerAboutLabel,
        ),
      ],
    );
  }
}
