import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/core/strings/app_strings.dart';
import 'package:modern_diary/src/features/secrets/domain/secret_models.dart';
import 'package:modern_diary/src/features/secrets/presentation/secrets_section.dart';
import 'package:atena_ui/atena_ui.dart';

import 'support/fake_secrets_data_source.dart';

ApiSecret _secret({
  int id = 1,
  String name = 'integracao_externa',
  bool isActive = true,
}) {
  return ApiSecret(
    id: id,
    name: name,
    tokenHint: 'abc123',
    isActive: isActive,
    permissions: const {
      PermissionArea.conhecimentos: SecretPermission(
        read: SensitivityLevel.complexo,
        create: true,
        write: true,
      ),
    },
    createdAt: DateTime(2026, 10, 21, 10),
    updatedAt: DateTime(2026, 10, 21, 10),
  );
}

Future<ToatController> _pumpSection(
  WidgetTester tester,
  FakeSecretsDataSource source,
) async {
  tester.view.physicalSize = const Size(1200, 1600);
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
          child: SecretsSection(repository: source, toat: toat),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return toat;
}

void _dismissAll(ToatController toat) {
  for (final message in [...toat.messages]) {
    toat.dismiss(message.id);
  }
}

void main() {
  testWidgets('lista credenciais com as permissões de cada área', (
    tester,
  ) async {
    await _pumpSection(tester, FakeSecretsDataSource(initial: [_secret()]));

    expect(find.text('integracao_externa'), findsOneWidget);
    expect(find.text(AppStrings.secretActive), findsOneWidget);
    expect(find.text(AppStrings.secretsTotal(1)), findsOneWidget);
    expect(
      find.text(
        AppStrings.secretPermissionLine(
          AppStrings.permissionAreaKnowledge,
          AppStrings.sensitivityComplex,
          create: true,
          write: true,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('mostra o estado vazio quando não há credencial', (tester) async {
    await _pumpSection(tester, FakeSecretsDataSource());

    expect(find.text(AppStrings.secretsEmptyTitle), findsOneWidget);
    expect(find.text(AppStrings.newSecret), findsOneWidget);
  });

  testWidgets('cria credencial, libera uma área e mostra o token', (
    tester,
  ) async {
    final source = FakeSecretsDataSource();
    final toat = await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.newSecret));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'integracao');
    await tester.tap(find.text(AppStrings.permissionAreaGoals));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.secretReadLabel), findsOneWidget);

    await tester.tap(find.text(AppStrings.secretCreate));
    await tester.pumpAndSettle();

    expect(source.secrets.single.permissions.keys, {PermissionArea.metas});
    expect(
      source.secrets.single.permissions[PermissionArea.metas]?.read,
      SensitivityLevel.publico,
    );

    expect(find.text(AppStrings.secretTokenTitle), findsOneWidget);
    expect(find.text('mds_token_integracao'), findsOneWidget);

    await tester.tap(find.text(AppStrings.secretTokenDone));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.secretTokenTitle), findsNothing);
    expect(find.text('integracao'), findsOneWidget);

    _dismissAll(toat);
  });

  testWidgets('recusa criar credencial sem área liberada', (tester) async {
    final source = FakeSecretsDataSource();
    await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.newSecret));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'integracao');
    await tester.tap(find.text(AppStrings.secretCreate));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.secretPermissionRequired), findsOneWidget);
    expect(source.secrets, isEmpty);
  });

  testWidgets('libera escrita pela linha de switch da área', (tester) async {
    final source = FakeSecretsDataSource();
    final toat = await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.newSecret));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'integracao');
    await tester.tap(find.text(AppStrings.permissionAreaGoals));
    await tester.pumpAndSettle();

    // Criar e Alterar aparecem como linhas com switch, mostrando o estado.
    final writeRow = find.ancestor(
      of: find.text(AppStrings.secretWriteLabel),
      matching: find.byType(AppSwitchRow),
    );
    expect(writeRow, findsOneWidget);
    expect(
      tester
          .widgetList<Switch>(find.byType(Switch))
          .where((widget) => widget.value),
      hasLength(1),
    );

    await tester.tap(find.text(AppStrings.secretWriteLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.secretCreate));
    await tester.pumpAndSettle();

    final permission = source.secrets.single.permissions[PermissionArea.metas];
    expect(permission?.write, isTrue);
    expect(permission?.create, isFalse);

    _dismissAll(toat);
  });

  testWidgets('revoga a credencial após confirmação', (tester) async {
    final source = FakeSecretsDataSource(initial: [_secret()]);
    final toat = await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.secretRevokeLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.secretRevokeAction));
    await tester.pumpAndSettle();

    expect(source.revokeCalls, 1);
    expect(find.text(AppStrings.secretRevokedBadge), findsOneWidget);
    expect(find.text(AppStrings.secretRevokeLabel), findsNothing);
    expect(find.text(AppStrings.secretRotateLabel), findsNothing);

    _dismissAll(toat);
  });

  testWidgets('auditoria lista as decisões da credencial', (tester) async {
    final source = FakeSecretsDataSource(initial: [_secret()]);
    source.audit.add(
      SecretAuditEntry(
        id: 1,
        area: 'conhecimentos',
        action: 'READ',
        result: 'DENIED',
        targetType: 'knowledge_item',
        targetId: 9,
        createdAt: DateTime(2026, 10, 21, 11),
      ),
    );
    await _pumpSection(tester, source);

    await tester.tap(find.text(AppStrings.secretAuditLabel));
    await tester.pumpAndSettle();

    expect(
      find.text(
        AppStrings.secretAuditLine(
          AppStrings.secretAuditActionLabel('READ'),
          AppStrings.permissionAreaKnowledge,
          AppStrings.secretAuditResultLabel('DENIED'),
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Conhecimento #9'), findsOneWidget);
    expect(find.text(AppStrings.secretAuditTotal(1)), findsOneWidget);
  });
}
