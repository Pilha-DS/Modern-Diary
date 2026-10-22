import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/agenda/presentation/agenda_controller.dart';
import 'package:modern_diary/src/features/agenda/presentation/dashboard_tab.dart';
import 'package:modern_diary/src/features/agenda/presentation/month_section.dart';
import 'package:modern_diary/src/features/home/presentation/home_navigation.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import 'support/fake_agenda_data_source.dart';
import 'support/fake_tags_data_source.dart';

void main() {
  final today = DateTime(2026, 10, 21);

  Future<AgendaController> controllerFor(WidgetTester tester) async {
    final controller = AgendaController(
      FakeAgendaDataSource(today: today),
      clock: () => today,
    );
    await controller.initialize();
    addTearDown(controller.dispose);
    return controller;
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required AgendaController controller,
    ValueChanged<HomeSection>? onOpen,
    ToatController? toat,
  }) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final toatController = toat ?? ToatController();
    if (toat == null) {
      addTearDown(toatController.dispose);
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DashboardTab(
              controller: controller,
              username: 'jonathan',
              tagsDataSource: FakeTagsDataSource(),
              toat: toatController,
              quickLinks: const [
                HomeQuickLink(
                  section: HomeSection.calendar,
                  icon: Icons.calendar_month_outlined,
                  label: AppStrings.calendarTab,
                ),
                HomeQuickLink(
                  section: HomeSection.goals,
                  icon: Icons.flag_outlined,
                  label: AppStrings.goalsTab,
                ),
                HomeQuickLink(
                  section: HomeSection.knowledge,
                  icon: Icons.hub_outlined,
                  label: AppStrings.knowledgeTab,
                ),
              ],
              navigation: onOpen == null
                  ? null
                  : HomeNavigation(
                      openTag: (_) {},
                      openGoal: (_) {},
                      openKnowledgeItem: (_) {},
                      openNote: (_) {},
                      openDay: (_) {},
                      openSection: onOpen,
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('o início troca a nota do dia pela seleção rápida de telas', (
    tester,
  ) async {
    final controller = await controllerFor(tester);
    await pumpDashboard(tester, controller: controller);

    expect(find.text(AppStrings.quickAccessTitle), findsOneWidget);
    expect(find.text(AppStrings.calendarTab), findsOneWidget);
    expect(find.text(AppStrings.goalsTab), findsOneWidget);
    expect(find.text(AppStrings.knowledgeTab), findsOneWidget);

    // A nota do dia saiu do início: ela é editada no dia do calendário.
    expect(find.text(AppStrings.noteTitle), findsNothing);
    expect(find.text(AppStrings.noteHint), findsNothing);
  });

  testWidgets('cada item da seleção rápida abre a tela escolhida', (
    tester,
  ) async {
    final controller = await controllerFor(tester);
    HomeSection? opened;
    await pumpDashboard(
      tester,
      controller: controller,
      onOpen: (section) => opened = section,
    );

    await tester.tap(find.text(AppStrings.goalsTab));
    await tester.pumpAndSettle();

    expect(opened, HomeSection.goals);
  });

  testWidgets('clicar no dia do início abre o painel do dia em modal', (
    tester,
  ) async {
    final controller = await controllerFor(tester);
    var openedSection = HomeSection.calendar;

    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final toat = ToatController();
    addTearDown(toat.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppColors.grayLight,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: DashboardTab(
              controller: controller,
              username: 'jonathan',
              tagsDataSource: FakeTagsDataSource(),
              toat: toat,
              quickLinks: const [
                HomeQuickLink(
                  section: HomeSection.calendar,
                  icon: Icons.calendar_month_outlined,
                  label: AppStrings.calendarTab,
                ),
              ],
              navigation: HomeNavigation(
                openTag: (_) {},
                openGoal: (_) {},
                openKnowledgeItem: (_) {},
                openNote: (_) {},
                openDay: (_) {},
                openSection: (section) => openedSection = section,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A dica abaixo do mês explica como abrir o dia.
    expect(find.text(AppStrings.dashboardDayHint), findsOneWidget);
    expect(find.text(AppStrings.greeting('jonathan')), findsOneWidget);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    // O modal abre por cima do início, sem trocar de tela.
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.text(AppStrings.dayTitle(DateTime(2026, 10, 15))),
      findsWidgets,
    );
    // O dia abre em leitura; as ações aparecem ao entrar no modo de edição.
    expect(find.text(AppStrings.noteTitle), findsWidgets);
    await tester.tap(find.text(AppStrings.editDay));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.newActivity), findsOneWidget);
    expect(find.text(AppStrings.greeting('jonathan')), findsOneWidget);
    expect(openedSection, HomeSection.calendar);
    // O dia escolhido fica selecionado no controller.
    expect(controller.selectedDay, DateTime(2026, 10, 15));

    // Fechar o modal volta ao início, sem ter saído dele.
    await tester.tap(find.byTooltip(AppStrings.close));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text(AppStrings.greeting('jonathan')), findsOneWidget);
    expect(find.text(AppStrings.quickAccessTitle), findsOneWidget);
  });

  testWidgets('o mês do início fica 30% menor que a metade da linha', (
    tester,
  ) async {
    final controller = await controllerFor(tester);
    await pumpDashboard(tester, controller: controller);

    final calendarWidth = tester.getSize(find.byType(MonthSection)).width;
    final menuWidth = tester
        .getSize(
          find
              .ancestor(
                of: find.text(AppStrings.quickAccessTitle),
                matching: find.byType(AppSurface),
              )
              .first,
        )
        .width;
    final rowWidth = calendarWidth + menuWidth + AppSpacing.md;

    // Antes o mês ocupava 5/9 da linha (55,6%); agora ocupa 40%.
    expect(calendarWidth / rowWidth, closeTo(0.4, 0.02));
    expect(calendarWidth / rowWidth, lessThan(5 / 9));
  });
}
