import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/domain/sensitivity_level.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/features/secrets/domain/secret_models.dart';
import 'package:modern_diary/src/features/secrets/presentation/secret_form_dialog.dart';
import 'package:modern_diary/src/features/secrets/presentation/secrets_controller.dart';

import 'support/fake_secrets_data_source.dart';

ApiSecret _secret(int id, {bool isActive = true}) {
  return ApiSecret(
    id: id,
    name: 'credencial_$id',
    tokenHint: 'abc$id',
    isActive: isActive,
    permissions: const {
      PermissionArea.metas: SecretPermission(
        read: SensitivityLevel.basico,
        create: true,
      ),
    },
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
  );
}

SecretDraft _draft({String name = 'nova_credencial'}) {
  return SecretDraft(
    name: name,
    permissions: const {
      PermissionArea.conhecimentos: SecretPermission(
        read: SensitivityLevel.complexo,
        create: true,
        write: true,
      ),
    },
  );
}

class _RejectingSecretsDataSource extends FakeSecretsDataSource {
  @override
  Future<SecretCreation> createSecret({
    required String name,
    required Map<PermissionArea, SecretPermission> permissions,
  }) async {
    throw const ApiException(
      code: 'PERMISSION_DENIED',
      message: 'Sua conta não pode criar credenciais.',
      statusCode: 403,
    );
  }
}

void main() {
  test('carrega a primeira página e expõe o total do meta', () async {
    final source = FakeSecretsDataSource(initial: [_secret(1), _secret(2)]);
    final controller = SecretsController(source);
    addTearDown(controller.dispose);

    final loading = controller.loadFirstPage();
    expect(controller.isLoading, isTrue);
    await loading;

    expect(controller.isLoading, isFalse);
    expect(controller.secrets, hasLength(2));
    expect(controller.total, 2);
    expect(controller.hasMore, isFalse);
  });

  test('cria a credencial, devolve o token e recarrega a lista', () async {
    final source = FakeSecretsDataSource();
    final controller = SecretsController(source);
    addTearDown(controller.dispose);

    final result = await controller.createSecret(_draft());

    expect(result.error, isNull);
    expect(result.creation?.token, 'mds_token_nova_credencial');
    expect(source.createCalls, 1);
    expect(controller.secrets.single.name, 'nova_credencial');
    expect(
      controller
          .secrets
          .single
          .permissions[PermissionArea.conhecimentos]
          ?.write,
      isTrue,
    );
    expect(controller.isCreating, isFalse);
  });

  test('falha na criação devolve o erro e mantém a lista', () async {
    final controller = SecretsController(_RejectingSecretsDataSource());
    addTearDown(controller.dispose);

    final result = await controller.createSecret(_draft());

    expect(result.creation, isNull);
    expect(result.error?.code, 'PERMISSION_DENIED');
    expect(controller.isCreating, isFalse);
  });

  test('carrega as próximas páginas sob demanda', () async {
    final source = FakeSecretsDataSource(
      initial: [for (var id = 1; id <= 12; id++) _secret(id)],
    );
    final controller = SecretsController(source);
    addTearDown(controller.dispose);

    await controller.loadFirstPage();
    expect(controller.secrets, hasLength(10));
    expect(controller.hasMore, isTrue);

    await controller.loadMore();

    expect(controller.secrets, hasLength(12));
    expect(controller.hasMore, isFalse);
  });

  test('troca o token e recarrega o hint novo', () async {
    final source = FakeSecretsDataSource(initial: [_secret(1)]);
    final controller = SecretsController(source);
    addTearDown(controller.dispose);
    await controller.loadFirstPage();

    final result = await controller.rotate(1);

    expect(result.creation?.token, 'mds_novo_1');
    expect(source.rotateCalls, 1);
    expect(controller.secrets.single.tokenHint, 'zzz999');
    expect(controller.isBusy(1), isFalse);
  });

  test('revoga a credencial e mantém o registro na lista', () async {
    final source = FakeSecretsDataSource(initial: [_secret(1)]);
    final controller = SecretsController(source);
    addTearDown(controller.dispose);
    await controller.loadFirstPage();

    final error = await controller.revoke(1);

    expect(error, isNull);
    expect(source.revokeCalls, 1);
    expect(controller.secrets.single.isRevoked, isTrue);
  });
}
