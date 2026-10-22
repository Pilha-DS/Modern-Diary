import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../domain/audit_models.dart';
import 'audit_controller.dart';
import 'audit_event_tile.dart';
import 'audit_graph_view.dart';

/// Histórico e grafo do dia escolhido na auditoria.
class AuditDayView extends StatelessWidget {
  const AuditDayView({super.key, required this.controller, this.navigation});

  final AuditController controller;
  final HomeNavigation? navigation;

  static const double _wideBreakpoint = 860;
  static const double _panelHeight = 520;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              AppStrings.dayTitle(controller.selectedDay),
              style: textTheme.titleMedium,
            ),
            Text(
              AppStrings.auditDayTotal(controller.total),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _content(context),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final error = controller.error;
    if (controller.isLoading) {
      return const StatusView.loading(title: AppStrings.auditLoading);
    }
    if (error != null) {
      return StatusView.error(
        title: AppStrings.auditErrorTitle,
        message: error.message,
        actionLabel: AppStrings.auditErrorRetry,
        onAction: controller.refresh,
      );
    }
    if (controller.events.isEmpty) {
      return const StatusView.empty(
        icon: Icons.history_rounded,
        title: AppStrings.auditEmptyTitle,
        message: AppStrings.auditEmptyMessage,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        final graph = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: wide ? _panelHeight : 420,
              child: AuditGraphView(
                graph: controller.graph,
                onNodeTap: _openNode,
              ),
            ),
            if (controller.graph.truncated) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.auditGraphTruncated,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );

        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              graph,
              const SizedBox(height: AppSpacing.md),
              _timeline(context, scrollable: false),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: graph),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: _panelHeight,
                child: _timeline(context, scrollable: true),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _timeline(BuildContext context, {required bool scrollable}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final event in controller.events)
          AuditEventTile(event: event, onTap: _eventTap(event)),
        if (controller.hasMore)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: AppButton(
              label: AppStrings.auditLoadMore,
              icon: Icons.expand_more_rounded,
              variant: AppButtonVariant.secondary,
              isLoading: controller.isLoadingMore,
              onPressed: controller.loadMore,
            ),
          ),
      ],
    );

    return AppSurface(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }

  VoidCallback? _eventTap(AuditEvent event) {
    final candidates = [event.source, if (event.target != null) event.target!];
    for (final entity in candidates) {
      if (_isNavigable(entity)) {
        return () => _open(entity);
      }
    }
    return null;
  }

  bool _isNavigable(AuditEntity entity) {
    if (navigation == null) {
      return false;
    }
    return switch (entity.type) {
      'knowledge' || 'goal' => int.tryParse(entity.ref) != null,
      'day' => DateTime.tryParse(entity.ref) != null,
      _ => false,
    };
  }

  void _open(AuditEntity entity) {
    final navigation = this.navigation;
    if (navigation == null) {
      return;
    }
    switch (entity.type) {
      case 'knowledge':
        final itemId = int.tryParse(entity.ref);
        if (itemId != null) {
          navigation.openKnowledgeItem(itemId);
        }
      case 'goal':
        final goalId = int.tryParse(entity.ref);
        if (goalId != null) {
          navigation.openGoal(goalId);
        }
      case 'day':
        final day = DateTime.tryParse(entity.ref);
        if (day != null) {
          navigation.openDay(day);
        }
    }
  }

  void _openNode(AuditGraphNode node) {
    final separator = node.id.indexOf(':');
    if (separator < 0) {
      return;
    }
    _open(
      AuditEntity(
        type: node.type,
        ref: node.id.substring(separator + 1),
        label: node.label,
      ),
    );
  }
}
