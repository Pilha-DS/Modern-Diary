import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/audit/domain/audit_models.dart';
import 'package:modern_diary/src/features/audit/presentation/about_me_section.dart';
import 'package:modern_diary/src/features/auth/domain/user.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_audit_data_source.dart';

final User _user = User(
  id: 1,
  username: 'jonathan',
  role: UserRole.user,
  createdAt: DateTime(2026, 1, 2),
);

DateTime get _today {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Future<void> _pumpSection(
  WidgetTester tester,
  FakeAuditDataSource source, {
  Size size = const Size(1200, 1800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: AboutMeSection(repository: source, user: _user),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra os dados da conta, o dia e o grafo das ações', (
    tester,
  ) async {
    final today = _today;
    final source = FakeAuditDataSource(
      events: [
        AuditEvent(
          id: 1,
          occurredAt: today.add(const Duration(hours: 9)),
          kind: AuditEventKind.create,
          source: const AuditEntity(type: 'knowledge', ref: '7', label: 'SQL'),
        ),
        AuditEvent(
          id: 2,
          occurredAt: today.add(const Duration(hours: 10)),
          kind: AuditEventKind.link,
          source: const AuditEntity(type: 'knowledge', ref: '7', label: 'SQL'),
          target: const AuditEntity(
            type: 'goal',
            ref: '3',
            label: 'Aprender SQL',
          ),
        ),
      ],
    );

    await _pumpSection(tester, source);

    expect(find.text(AppStrings.aboutMeTitle), findsOneWidget);
    expect(find.text(AppStrings.auditTitle), findsOneWidget);
    expect(find.text('jonathan'), findsOneWidget);
    expect(find.text(AppStrings.dayTitle(today)), findsOneWidget);
    expect(find.text(AppStrings.auditDayTotal(2)), findsOneWidget);
    expect(find.text('Criou o conhecimento «SQL».'), findsOneWidget);
    expect(find.text('Conectou «SQL» a «Aprender SQL».'), findsOneWidget);
    expect(find.byType(NetworkGraph), findsOneWidget);
  });

  testWidgets('dia sem ações mostra o estado vazio', (tester) async {
    await _pumpSection(tester, FakeAuditDataSource());

    expect(find.text(AppStrings.auditEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.auditEmptyMessage), findsOneWidget);
    expect(find.byType(NetworkGraph), findsNothing);
  });

  testWidgets('erro da API mostra o aviso e o retry', (tester) async {
    await _pumpSection(
      tester,
      FakeAuditDataSource(
        error: const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Sem conexão com o servidor.',
        ),
      ),
    );

    expect(find.text(AppStrings.auditErrorTitle), findsOneWidget);
    expect(find.text('Sem conexão com o servidor.'), findsOneWidget);
    expect(find.text(AppStrings.auditErrorRetry), findsOneWidget);
  });

  testWidgets('escolher outro dia da auditoria recarrega o histórico', (
    tester,
  ) async {
    final today = _today;
    final other = today.day > 1
        ? today.subtract(const Duration(days: 1))
        : today.add(const Duration(days: 1));
    final source = FakeAuditDataSource(
      events: [
        AuditEvent(
          id: 1,
          occurredAt: today.add(const Duration(hours: 9)),
          kind: AuditEventKind.create,
          source: const AuditEntity(type: 'knowledge', ref: '7', label: 'Hoje'),
        ),
        AuditEvent(
          id: 2,
          occurredAt: other.add(const Duration(hours: 9)),
          kind: AuditEventKind.create,
          source: const AuditEntity(
            type: 'knowledge',
            ref: '8',
            label: 'Ontem',
          ),
        ),
      ],
    );

    await _pumpSection(tester, source);
    expect(find.text('Criou o conhecimento «Hoje».'), findsOneWidget);

    await tester.tap(find.text('${other.day}').last);
    await tester.pumpAndSettle();

    expect(find.text('Criou o conhecimento «Ontem».'), findsOneWidget);
    expect(find.text('Criou o conhecimento «Hoje».'), findsNothing);
  });
}
