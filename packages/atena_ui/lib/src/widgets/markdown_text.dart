import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Renderiza um subconjunto de markdown, sem dependências externas:
/// títulos (`#`), listas (`-`), checklists (`- [x]`), citação (`>`), blocos de
/// código e negrito, itálico, código e link em linha.
class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.markdown, {
    super.key,
    this.emptyText,
    this.baseStyle,
  });

  final String markdown;
  final String? emptyText;
  final TextStyle? baseStyle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final style = baseStyle ?? textTheme.bodyMedium ?? const TextStyle();

    final trimmed = markdown.trim();
    if (trimmed.isEmpty) {
      return Text(
        emptyText ?? '',
        style: style.copyWith(color: colorScheme.onSurfaceVariant),
      );
    }

    final blocks = _buildBlocks(context, trimmed, style, textTheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<Widget> _buildBlocks(
    BuildContext context,
    String source,
    TextStyle style,
    TextTheme textTheme,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final blocks = <Widget>[];
    final lines = source.split('\n');
    var index = 0;

    while (index < lines.length) {
      final line = lines[index];
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        final code = <String>[];
        index++;
        while (index < lines.length && !lines[index].trim().startsWith('```')) {
          code.add(lines[index]);
          index++;
        }
        index++;
        blocks.add(_codeBlock(context, code.join('\n')));
        continue;
      }

      if (trimmed.isEmpty) {
        blocks.add(const SizedBox(height: AppSpacing.sm));
        index++;
        continue;
      }

      final heading = RegExp(r'^(#{1,3})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        final level = heading.group(1)!.length;
        final headingStyle = switch (level) {
          1 => textTheme.headlineSmall,
          2 => textTheme.titleLarge,
          _ => textTheme.titleMedium,
        };
        blocks.add(
          _spaced(
            Text.rich(
              _inline(context, heading.group(2)!, headingStyle ?? style),
            ),
          ),
        );
        index++;
        continue;
      }

      final checklist = RegExp(r'^[-*]\s+\[( |x|X)\]\s+(.*)$')
          .firstMatch(trimmed);
      if (checklist != null) {
        final checked = checklist.group(1)!.toLowerCase() == 'x';
        blocks.add(
          _bulletRow(
            context,
            icon: checked
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            iconColor: checked
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            text: checklist.group(2)!,
            style: style.copyWith(
              decoration: checked ? TextDecoration.lineThrough : null,
              color: checked ? colorScheme.onSurfaceVariant : null,
            ),
          ),
        );
        index++;
        continue;
      }

      final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        blocks.add(_bulletRow(context, text: bullet.group(1)!, style: style));
        index++;
        continue;
      }

      final numbered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (numbered != null) {
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: AppSpacing.lg,
                  child: Text(
                    '${numbered.group(1)}.',
                    style: style.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: Text.rich(_inline(context, numbered.group(2)!, style)),
                ),
              ],
            ),
          ),
        );
        index++;
        continue;
      }

      if (trimmed.startsWith('>')) {
        blocks.add(
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Text.rich(
              _inline(
                context,
                trimmed.substring(1).trim(),
                style.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        );
        index++;
        continue;
      }

      blocks.add(_spaced(Text.rich(_inline(context, trimmed, style))));
      index++;
    }

    return blocks;
  }

  Widget _spaced(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: child,
    );
  }

  Widget _bulletRow(
    BuildContext context, {
    required String text,
    required TextStyle style,
    IconData? icon,
    Color? iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: AppSpacing.iconSize - 2,
                color: iconColor,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs, top: 2),
              child: Icon(
                Icons.circle,
                size: 6,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text.rich(_inline(context, text, style))),
        ],
      ),
    );
  }

  Widget _codeBlock(BuildContext context, String code) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(
        code.isEmpty ? ' ' : code,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.5,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  TextSpan _inline(BuildContext context, String text, TextStyle style) {
    final colorScheme = Theme.of(context).colorScheme;
    final pattern = RegExp(
      r'(\*\*[^*]+\*\*|__[^_]+__|\*[^*]+\*|_[^_]+_|`[^`]+`|\[[^\]]+\]\([^)]+\))',
    );
    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final token = match.group(0)!;
      if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(
          TextSpan(
            text: token.substring(2, token.length - 2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (token.startsWith('`')) {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.onSurface,
            ),
          ),
        );
      } else if (token.startsWith('[')) {
        final split = token.indexOf('](');
        spans.add(
          TextSpan(
            text: token.substring(1, split),
            style: TextStyle(
              color: colorScheme.primary,
              decoration: TextDecoration.underline,
              decorationColor: colorScheme.primary,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: token.substring(1, token.length - 1),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return TextSpan(style: style, children: spans);
  }
}
