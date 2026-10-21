import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'app_surface.dart';

/// Modal padrão do projeto: superfície sólida, sem borda, com título,
/// botão de fechar e conteúdo rolável. Usado para editar algo sem sair da
/// tela atual.
class AppDialogSurface extends StatelessWidget {
  const AppDialogSurface({
    super.key,
    required this.title,
    required this.closeLabel,
    required this.child,
    this.maxWidth = 560,
  });

  final String title;

  /// Rótulo do botão de fechar, também lido pelo leitor de tela.
  final String closeLabel;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: AppSurface(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: closeLabel,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: AppSpacing.iconSize,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Abre o [AppDialogSurface] e devolve o valor entregue pelo conteúdo ao
/// fechar, ou `null` quando o usuário descarta o modal.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  required String closeLabel,
  required Widget child,
  double maxWidth = 560,
}) {
  return showDialog<T>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: AppDialogSurface(
        title: title,
        closeLabel: closeLabel,
        maxWidth: maxWidth,
        child: child,
      ),
    ),
  );
}
