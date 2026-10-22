import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/domain/sensitivity_level.dart';
import '../../../core/strings/app_strings.dart';
import '../domain/secret_models.dart';

/// Dados coletados no formulário de credencial.
class SecretDraft {
  const SecretDraft({required this.name, required this.permissions});

  final String name;

  /// Área ausente não está liberada para a credencial.
  final Map<PermissionArea, SecretPermission> permissions;
}

Future<SecretDraft?> showSecretFormDialog(
  BuildContext context, {
  required String title,
  required String submitLabel,
  ApiSecret? secret,
}) {
  return showAppDialog<SecretDraft>(
    context,
    title: title,
    closeLabel: AppStrings.close,
    // Largura de formulário do projeto: campo muito largo dificulta a leitura
    // e empurra os botões uns contra os outros.
    maxWidth: AppSpacing.maxFormWidth,
    child: _SecretFormBody(submitLabel: submitLabel, secret: secret),
  );
}

class _SecretFormBody extends StatefulWidget {
  const _SecretFormBody({required this.submitLabel, this.secret});

  final String submitLabel;
  final ApiSecret? secret;

  @override
  State<_SecretFormBody> createState() => _SecretFormBodyState();
}

class _SecretFormBodyState extends State<_SecretFormBody> {
  late final TextEditingController _nameController;
  late Map<PermissionArea, SecretPermission> _permissions;
  String? _nameError;
  String? _permissionsError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.secret?.name ?? '');
    _permissions = Map.of(widget.secret?.permissions ?? const {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _setPermission(PermissionArea area, SecretPermission? permission) {
    setState(() {
      if (permission == null) {
        _permissions.remove(area);
      } else {
        _permissions[area] = permission;
      }
      _permissionsError = null;
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? AppStrings.secretNameRequired : null;
      _permissionsError = _permissions.isEmpty
          ? AppStrings.secretPermissionRequired
          : null;
    });
    if (_nameError != null || _permissionsError != null) {
      return;
    }

    Navigator.of(
      context,
    ).pop(SecretDraft(name: name, permissions: Map.unmodifiable(_permissions)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: AppStrings.secretNameLabel,
            hintText: AppStrings.secretNameHint,
            errorText: _nameError,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.secretPermissionsLabel, style: textTheme.titleSmall),
        if (_permissionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              _permissionsError!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        for (final area in PermissionArea.values) ...[
          _AreaPermissionEditor(
            area: area,
            permission: _permissions[area],
            onChanged: (permission) => _setPermission(area, permission),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        const InlineMessage(
          message: AppStrings.secretCreateRule,
          variant: InlineMessageVariant.info,
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.cancel),
            ),
            AppButton(
              label: widget.submitLabel,
              icon: Icons.check_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}

/// Nível máximo de leitura e as duas operações de escrita de uma área.
/// Sem permissão, a área não é enviada e fica negada por padrão.
class _AreaPermissionEditor extends StatelessWidget {
  const _AreaPermissionEditor({
    required this.area,
    required this.permission,
    required this.onChanged,
  });

  final PermissionArea area;
  final SecretPermission? permission;
  final ValueChanged<SecretPermission?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final current = permission;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSwitchRow(
              label: AppStrings.permissionAreaLabel(area.apiValue),
              value: current != null,
              onChanged: (enabled) => onChanged(
                enabled
                    ? const SecretPermission(read: SensitivityLevel.publico)
                    : null,
              ),
            ),
            if (current != null) ...[
              const SizedBox(height: AppSpacing.xs),
              // Rótulo fixo acima do campo escolhido: o campo fica branco,
              // separado do fundo do cartão, e não some na tela.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppStrings.secretReadLabel,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<SensitivityLevel>(
                      initialValue: current.read,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        isDense: true,
                        fillColor: colorScheme.surface,
                      ),
                      items: [
                        for (final level in SensitivityLevel.values)
                          DropdownMenuItem(
                            value: level,
                            child: Text(
                              AppStrings.sensitivityLabelOf(level.apiValue),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (level) {
                        if (level != null) {
                          onChanged(current.copyWith(read: level));
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // As duas operações de escrita ficam lado a lado, cada uma
                    // com o switch mostrando se está liberada. Empilham em tela
                    // estreita, sem se sobrepor.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final rows = [
                          AppSwitchRow(
                            icon: Icons.add_rounded,
                            label: AppStrings.secretCreateLabel,
                            value: current.create,
                            color: colorScheme.surface,
                            onChanged: (value) =>
                                onChanged(current.copyWith(create: value)),
                          ),
                          AppSwitchRow(
                            icon: Icons.edit_outlined,
                            label: AppStrings.secretWriteLabel,
                            value: current.write,
                            color: colorScheme.surface,
                            onChanged: (value) =>
                                onChanged(current.copyWith(write: value)),
                          ),
                        ];
                        if (constraints.maxWidth < 340) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              rows.first,
                              const SizedBox(height: AppSpacing.xs),
                              rows.last,
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: rows.first),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: rows.last),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
