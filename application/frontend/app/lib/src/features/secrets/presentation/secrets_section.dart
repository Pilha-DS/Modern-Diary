import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../data/secrets_repository.dart';
import '../domain/secret_models.dart';
import 'secret_audit_dialog.dart';
import 'secret_form_dialog.dart';
import 'secret_token_dialog.dart';
import 'secrets_controller.dart';

/// Credenciais de integração: criação, permissões, rotação, revogação e
/// auditoria. O token só é mostrado na criação e na troca.
class SecretsSection extends StatefulWidget {
  const SecretsSection({
    super.key,
    required this.repository,
    required this.toat,
  });

  final SecretsDataSource repository;
  final ToatController toat;

  @override
  State<SecretsSection> createState() => _SecretsSectionState();
}

class _SecretsSectionState extends State<SecretsSection> {
  late final SecretsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SecretsController(widget.repository)..loadFirstPage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final draft = await showSecretFormDialog(
      context,
      title: AppStrings.newSecret,
      submitLabel: AppStrings.secretCreate,
    );
    if (draft == null || !mounted) {
      return;
    }

    final result = await _controller.createSecret(draft);
    if (!mounted) {
      return;
    }
    if (result.error != null) {
      widget.toat.show(result.error!.message, variant: ToatVariant.error);
      return;
    }
    widget.toat.show(AppStrings.secretCreated, variant: ToatVariant.success);
    final creation = result.creation;
    if (creation != null) {
      await _showToken(creation);
    }
  }

  Future<void> _edit(ApiSecret secret) async {
    final draft = await showSecretFormDialog(
      context,
      title: AppStrings.editSecret,
      submitLabel: AppStrings.secretSave,
      secret: secret,
    );
    if (draft == null || !mounted) {
      return;
    }

    final error = await _controller.updateSecret(secret.id, draft);
    _notify(error, AppStrings.secretUpdated);
  }

  Future<void> _rotate(ApiSecret secret) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.secretRotateTitle,
      message: AppStrings.secretRotateMessage(secret.name),
      confirmLabel: AppStrings.secretRotateAction,
      cancelLabel: AppStrings.cancel,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final result = await _controller.rotate(secret.id);
    if (!mounted) {
      return;
    }
    if (result.error != null) {
      widget.toat.show(result.error!.message, variant: ToatVariant.error);
      return;
    }
    widget.toat.show(AppStrings.secretRotated, variant: ToatVariant.success);
    final creation = result.creation;
    if (creation != null) {
      await _showToken(creation);
    }
  }

  Future<void> _revoke(ApiSecret secret) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.secretRevokeTitle,
      message: AppStrings.secretRevokeMessage(secret.name),
      confirmLabel: AppStrings.secretRevokeAction,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.danger,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final error = await _controller.revoke(secret.id);
    _notify(error, AppStrings.secretRevoked);
  }

  Future<void> _showToken(SecretCreation creation) {
    return showSecretTokenDialog(
      context,
      creation: creation,
      onCopy: _copyToken,
    );
  }

  Future<void> _copyToken(String token) async {
    await Clipboard.setData(ClipboardData(text: token));
    if (!mounted) {
      return;
    }
    widget.toat.show(
      AppStrings.secretTokenCopied,
      variant: ToatVariant.success,
    );
  }

  Future<void> _openAudit(ApiSecret secret) {
    return showSecretAuditDialog(
      context,
      dataSource: widget.repository,
      secret: secret,
    );
  }

  void _notify(ApiException? error, String successMessage) {
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? successMessage,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(AppStrings.secretsTitle, style: textTheme.titleMedium),
                if (!_controller.isLoading)
                  Text(
                    AppStrings.secretsTotal(_controller.total),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: AppStrings.refresh,
                  onPressed: _controller.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                AppButton(
                  label: AppStrings.newSecret,
                  icon: Icons.add_rounded,
                  isLoading: _controller.isCreating,
                  onPressed: _controller.isCreating ? null : _create,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.secretsSubtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_controller.isLoading)
          const StatusView.loading(title: AppStrings.secretsLoading)
        else if (_controller.error != null && _controller.secrets.isEmpty)
          StatusView.error(
            title: AppStrings.secretsErrorTitle,
            message: _controller.error!.message,
            actionLabel: AppStrings.retry,
            onAction: _controller.loadFirstPage,
          )
        else if (_controller.secrets.isEmpty)
          const StatusView.empty(
            icon: Icons.vpn_key_outlined,
            title: AppStrings.secretsEmptyTitle,
            message: AppStrings.secretsEmptyMessage,
          )
        else ...[
          if (_controller.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: InlineMessage(
                message: _controller.error!.message,
                variant: InlineMessageVariant.error,
              ),
            ),
          AppCardGrid(
            minCardWidth: 420,
            maxColumns: 2,
            children: [
              for (final secret in _controller.secrets)
                _SecretCard(
                  secret: secret,
                  isBusy: _controller.isBusy(secret.id),
                  onEdit: () => _edit(secret),
                  onRotate: () => _rotate(secret),
                  onRevoke: () => _revoke(secret),
                  onOpenAudit: () => _openAudit(secret),
                ),
            ],
          ),
          if (_controller.hasMore) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: AppButton(
                label: AppStrings.secretsLoadMore,
                variant: AppButtonVariant.secondary,
                isLoading: _controller.isLoadingMore,
                onPressed: _controller.loadMore,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _SecretCard extends StatelessWidget {
  const _SecretCard({
    required this.secret,
    required this.isBusy,
    required this.onEdit,
    required this.onRotate,
    required this.onRevoke,
    required this.onOpenAudit,
  });

  final ApiSecret secret;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onRotate;
  final VoidCallback onRevoke;
  final VoidCallback onOpenAudit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);
    final muted = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  secret.name,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppChip(
                icon: secret.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.block_rounded,
                label: secret.isActive
                    ? AppStrings.secretActive
                    : AppStrings.secretRevokedBadge,
              ),
              if (secret.isActive && !isBusy)
                IconButton(
                  tooltip: AppStrings.secretEditAction,
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: AppSpacing.iconSize,
                  ),
                ),
              if (isBusy)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: SizedBox.square(
                    dimension: AppSpacing.iconSize,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppStrings.secretHint(secret.tokenHint),
            style: muted?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            [
              AppStrings.secretCreatedAt(secret.createdAt),
              secret.lastUsedAt == null
                  ? AppStrings.secretNeverUsed
                  : AppStrings.secretLastUsed(secret.lastUsedAt!),
            ].join(' · '),
            style: muted,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (secret.permissions.isEmpty)
            Text(AppStrings.secretNoPermission, style: muted)
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (area, permission) in secret.orderedPermissions)
                  AppChip(
                    icon: Icons.shield_outlined,
                    label: AppStrings.secretPermissionLine(
                      AppStrings.permissionAreaLabel(area.apiValue),
                      AppStrings.sensitivityLabelOf(permission.read.apiValue),
                      create: permission.create,
                      write: permission.write,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.sm),
          // A grade iguala a altura dos cartões da linha: o espaço extra fica
          // antes das ações, que seguem no rodapé de todos.
          const Spacer(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed: isBusy ? null : onOpenAudit,
                icon: const Icon(
                  Icons.history_rounded,
                  size: AppSpacing.iconSize,
                ),
                label: const Text(AppStrings.secretAuditLabel),
              ),
              if (secret.isActive)
                TextButton.icon(
                  onPressed: isBusy ? null : onRotate,
                  style: TextButton.styleFrom(
                    foregroundColor: semanticColors.warning,
                  ),
                  icon: const Icon(
                    Icons.autorenew_rounded,
                    size: AppSpacing.iconSize,
                  ),
                  label: const Text(AppStrings.secretRotateLabel),
                ),
              if (secret.isActive)
                TextButton.icon(
                  onPressed: isBusy ? null : onRevoke,
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                  icon: const Icon(
                    Icons.block_rounded,
                    size: AppSpacing.iconSize,
                  ),
                  label: const Text(AppStrings.secretRevokeLabel),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
