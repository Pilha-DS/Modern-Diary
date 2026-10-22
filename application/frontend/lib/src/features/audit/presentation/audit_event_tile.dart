import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/audit_models.dart';

/// Rótulo exibido para um registro: o dia vira data curta.
String auditEntityLabel(AuditEntity entity) {
  if (entity.type == 'day') {
    final day = DateTime.tryParse(entity.ref);
    return day == null ? entity.label : AppStrings.shortDate(day);
  }
  return entity.label;
}

/// Frase da ação, montada a partir do tipo e do registro tocado.
String auditEventPhrase(AuditEvent event) {
  final source = auditEntityLabel(event.source);
  return switch (event.kind) {
    AuditEventKind.create => AppStrings.auditCreated(
      AppStrings.auditEntityNoun(event.source.type),
      source,
    ),
    AuditEventKind.update => AppStrings.auditUpdated(
      AppStrings.auditEntityNoun(event.source.type),
      source,
    ),
    AuditEventKind.delete => AppStrings.auditDeleted(
      AppStrings.auditEntityNoun(event.source.type),
      source,
    ),
    AuditEventKind.link => AppStrings.auditLinked(
      source,
      auditEntityLabel(event.target ?? event.source),
    ),
    AuditEventKind.unlink => AppStrings.auditUnlinked(
      source,
      auditEntityLabel(event.target ?? event.source),
    ),
  };
}

/// Uma linha do histórico do dia: horário, ação e o registro tocado.
class AuditEventTile extends StatelessWidget {
  const AuditEventTile({super.key, required this.event, this.onTap});

  final AuditEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _KindBadge(kind: event.kind),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppStrings.shortTime(event.occurredAt),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  auditEventPhrase(event),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppSpacing.iconSize,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final AuditEventKind kind;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = AppSemanticColors.of(context);
    final (background, foreground, icon) = switch (kind) {
      AuditEventKind.create => (
        semanticColors.brandSoft,
        semanticColors.brandDeep,
        Icons.add_rounded,
      ),
      AuditEventKind.update => (
        colorScheme.primaryContainer,
        colorScheme.primary,
        Icons.edit_outlined,
      ),
      AuditEventKind.delete => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.delete_outline_rounded,
      ),
      AuditEventKind.link => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.link_rounded,
      ),
      AuditEventKind.unlink => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.link_off_rounded,
      ),
    };

    return Container(
      width: AppSpacing.lg,
      height: AppSpacing.lg,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: AppSpacing.iconSize - 4, color: foreground),
    );
  }
}
