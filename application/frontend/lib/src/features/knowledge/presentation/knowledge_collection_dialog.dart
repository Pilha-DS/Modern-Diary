import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/strings/app_strings.dart';

/// Modal de uma coleção do conhecimento: metas, conexões ou links.
///
/// A lista vive aqui, então adicionar e remover atualizam o modal na hora,
/// sem fechar e reabrir. Quem chama executa a API e devolve o resultado.
Future<void> showKnowledgeCollectionDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> entries,
  required IconData icon,
  required String emptyMessage,
  required String addLabel,
  required String Function(T entry) labelOf,
  required String Function(T entry) removeLabelOf,
  required Future<T?> Function(List<T> current) onAdd,
  required Future<bool> Function(T entry, List<T> current) onRemove,
  ValueChanged<T>? onEntryTap,
}) {
  return showAppDialog<void>(
    context,
    title: title,
    closeLabel: AppStrings.close,
    maxWidth: 520,
    child: _CollectionBody<T>(
      title: title,
      entries: entries,
      icon: icon,
      emptyMessage: emptyMessage,
      addLabel: addLabel,
      labelOf: labelOf,
      removeLabelOf: removeLabelOf,
      onAdd: onAdd,
      onRemove: onRemove,
      onEntryTap: onEntryTap,
    ),
  );
}

class _CollectionBody<T> extends StatefulWidget {
  const _CollectionBody({
    required this.title,
    required this.entries,
    required this.icon,
    required this.emptyMessage,
    required this.addLabel,
    required this.labelOf,
    required this.removeLabelOf,
    required this.onAdd,
    required this.onRemove,
    required this.onEntryTap,
  });

  final String title;
  final List<T> entries;
  final IconData icon;
  final String emptyMessage;
  final String addLabel;
  final String Function(T entry) labelOf;
  final String Function(T entry) removeLabelOf;
  final Future<T?> Function(List<T> current) onAdd;
  final Future<bool> Function(T entry, List<T> current) onRemove;
  final ValueChanged<T>? onEntryTap;

  @override
  State<_CollectionBody<T>> createState() => _CollectionBodyState<T>();
}

class _CollectionBodyState<T> extends State<_CollectionBody<T>> {
  late List<T> _entries = [...widget.entries];
  bool _isAdding = false;
  int? _removingIndex;

  Future<void> _add() async {
    if (_isAdding) {
      return;
    }
    setState(() => _isAdding = true);
    final added = await widget.onAdd(List.unmodifiable(_entries));
    if (!mounted) {
      return;
    }
    setState(() {
      _isAdding = false;
      if (added != null) {
        _entries = [..._entries, added];
      }
    });
  }

  Future<void> _remove(int index) async {
    if (_removingIndex != null) {
      return;
    }
    setState(() => _removingIndex = index);
    final removed = await widget.onRemove(
      _entries[index],
      List.unmodifiable(_entries),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _removingIndex = null;
      if (removed) {
        _entries = [
          for (var position = 0; position < _entries.length; position++)
            if (position != index) _entries[position],
        ];
      }
    });
  }

  void _openEntry(int index) {
    final entry = _entries[index];
    Navigator.of(context).maybePop();
    widget.onEntryTap!(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_entries.isEmpty)
          StatusView.empty(
            icon: widget.icon,
            title: widget.title,
            message: widget.emptyMessage,
          )
        else
          for (var index = 0; index < _entries.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: _CollectionEntry(
                icon: widget.icon,
                label: widget.labelOf(_entries[index]),
                removeLabel: widget.removeLabelOf(_entries[index]),
                isBusy: _removingIndex == index,
                onTap: widget.onEntryTap == null
                    ? null
                    : () => _openEntry(index),
                onRemove: _removingIndex == null ? () => _remove(index) : null,
              ),
            ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: widget.addLabel,
          icon: Icons.add_rounded,
          variant: AppButtonVariant.secondary,
          isLoading: _isAdding,
          onPressed: _isAdding ? null : _add,
        ),
      ],
    );
  }
}

class _CollectionEntry extends StatelessWidget {
  const _CollectionEntry({
    required this.icon,
    required this.label,
    required this.removeLabel,
    required this.isBusy,
    required this.onTap,
    required this.onRemove,
  });

  final IconData icon;
  final String label;
  final String removeLabel;
  final bool isBusy;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final content = Row(
      children: [
        Icon(icon, size: AppSpacing.iconSize, color: colorScheme.onSurface),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
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
    );

    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.xs,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: onTap == null
                ? content
                : InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: onTap,
                    child: Semantics(
                      button: true,
                      label: AppStrings.openItemLabel(label),
                      excludeSemantics: true,
                      child: content,
                    ),
                  ),
          ),
          if (isBusy)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.sm),
              child: SizedBox.square(
                dimension: AppSpacing.iconSize - 4,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (onRemove != null)
            IconButton(
              tooltip: removeLabel,
              onPressed: onRemove,
              color: colorScheme.onSurfaceVariant,
              icon: const Icon(Icons.close_rounded, size: AppSpacing.iconSize),
            ),
        ],
      ),
    );
  }
}
