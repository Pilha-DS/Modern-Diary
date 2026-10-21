import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/user.dart';
import '../data/users_repository.dart';
import 'users_controller.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({super.key, required this.repository});

  final UsersRepository repository;

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  late final UsersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = UsersController(widget.repository)..loadFirstPage();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return AppSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(AppStrings.usersTitle, style: textTheme.titleMedium),
                  if (!_controller.isLoading && _controller.error == null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppStrings.usersTotal(_controller.total),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    tooltip: AppStrings.refresh,
                    onPressed: _controller.isLoading
                        ? null
                        : _controller.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_controller.isLoading)
                const StatusView.loading(title: AppStrings.loadingUsers)
              else if (_controller.error != null && _controller.users.isEmpty)
                StatusView.error(
                  title: AppStrings.usersErrorTitle,
                  message: _controller.error!.message,
                  actionLabel: AppStrings.retry,
                  onAction: _controller.loadFirstPage,
                )
              else if (_controller.users.isEmpty)
                const StatusView.empty(
                  icon: Icons.people_outline_rounded,
                  title: AppStrings.usersEmptyTitle,
                  message: AppStrings.usersEmptyMessage,
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
                for (final user in _controller.users) _UserRow(user: user),
                if (_controller.hasMore) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: AppStrings.usersLoadMore,
                    onPressed: _controller.loadMore,
                    variant: AppButtonVariant.secondary,
                    isLoading: _controller.isLoadingMore,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final roleLabel = AppStrings.roleLabel(user.role.apiValue);

    return Semantics(
      container: true,
      label: '${user.username}, $roleLabel',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: AppSpacing.xxl,
              height: AppSpacing.xxl,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                user.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            RoleBadge(role: user.role.apiValue, label: roleLabel),
          ],
        ),
      ),
    );
  }
}
