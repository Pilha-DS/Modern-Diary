import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../data/secrets_repository.dart';
import '../domain/secret_models.dart';

/// Histórico de acessos da credencial, paginado pelo back.
Future<void> showSecretAuditDialog(
  BuildContext context, {
  required SecretsDataSource dataSource,
  required ApiSecret secret,
}) {
  return showAppDialog<void>(
    context,
    title: AppStrings.secretAuditTitle(secret.name),
    closeLabel: AppStrings.close,
    maxWidth: 560,
    child: _SecretAuditBody(dataSource: dataSource, secret: secret),
  );
}

class _SecretAuditBody extends StatefulWidget {
  const _SecretAuditBody({required this.dataSource, required this.secret});

  final SecretsDataSource dataSource;
  final ApiSecret secret;

  @override
  State<_SecretAuditBody> createState() => _SecretAuditBodyState();
}

class _SecretAuditBodyState extends State<_SecretAuditBody> {
  static const int _perPage = 12;

  List<SecretAuditEntry> _entries = const [];
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  bool get _hasMore => _page < _totalPages;

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await widget.dataSource.fetchAudit(
        widget.secret.id,
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = page.entries;
        _page = page.page;
        _total = page.total;
        _totalPages = page.totalPages;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final page = await widget.dataSource.fetchAudit(
        widget.secret.id,
        page: _page + 1,
        perPage: _perPage,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = [..._entries, ...page.entries];
        _page = page.page;
        _total = page.total;
        _totalPages = page.totalPages;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading && _entries.isEmpty) {
      return const StatusView.loading(title: AppStrings.secretAuditLoading);
    }
    if (_error != null && _entries.isEmpty) {
      return StatusView.error(
        title: AppStrings.secretAuditErrorTitle,
        message: _error!.message,
        actionLabel: AppStrings.retry,
        onAction: _loadFirstPage,
      );
    }
    if (_entries.isEmpty) {
      return const StatusView.empty(
        icon: Icons.history_rounded,
        title: AppStrings.secretAuditEmptyTitle,
        message: AppStrings.secretAuditEmptyMessage,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.secretAuditTotal(_total),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final entry in _entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _AuditRow(entry: entry),
          ),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppButton(
              label: AppStrings.secretAuditLoadMore,
              variant: AppButtonVariant.ghost,
              isLoading: _isLoadingMore,
              onPressed: _loadMore,
            ),
          ),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});

  final SecretAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final targetLabel = AppStrings.secretAuditTargetLabel(entry.targetType);

    final details = [
      if (targetLabel != null)
        entry.targetId == null
            ? targetLabel
            : '$targetLabel #${entry.targetId}',
      AppStrings.secretAuditTime(entry.createdAt),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            entry.isDenied
                ? Icons.block_rounded
                : Icons.check_circle_outline_rounded,
            size: AppSpacing.iconSize,
            color: entry.isDenied ? colorScheme.error : colorScheme.onSurface,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.secretAuditLine(
                    AppStrings.secretAuditActionLabel(entry.action),
                    AppStrings.permissionAreaLabel(entry.area),
                    AppStrings.secretAuditResultLabel(entry.result),
                  ),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  details,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
