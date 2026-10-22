import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import 'markdown_text.dart';

/// Comando do editor que altera o texto no ponto do cursor.
enum MarkdownCommand {
  heading,
  bold,
  italic,
  bulletList,
  checklist,
  quote,
  code,
  link,
}

/// Textos do [MarkdownEditor]. O package não conhece o idioma da aplicação.
class MarkdownEditorLabels {
  const MarkdownEditorLabels({
    required this.emptyPreview,
    required this.edit,
    required this.done,
    this.label,
    this.hint,
    this.commands = const {},
    this.countLabel,
  });

  /// Texto exibido quando ainda não há conteúdo.
  final String emptyPreview;

  /// Ação/rótulo de leitura: "Clique para editar".
  final String edit;

  /// Ação que encerra a edição e volta a renderizar.
  final String done;

  /// Título exibido acima do conteúdo; `null` esconde o título.
  final String? label;
  final String? hint;

  /// Comandos da barra de formatação; vazio esconde a barra.
  final Map<MarkdownCommand, String> commands;

  /// Rodapé com a contagem; `null` esconde a contagem.
  final String Function(int characters, int words)? countLabel;
}

/// Campo de markdown que mostra o texto renderizado e só vira texto puro
/// quando o usuário clica nele.
///
/// Ao sair do campo, volta a renderizar. Em espaço largo a barra de comandos
/// fica acima do texto puro; em espaço estreito ela quebra em linhas. Use
/// `startInEdit` para abrir direto no texto puro (ex.: dentro de um formulário
/// de edição explícito).
///
/// ```dart
/// MarkdownEditor(
///   controller: _contentController,
///   labels: const MarkdownEditorLabels(
///     emptyPreview: 'O texto aparece aqui.',
///     edit: 'Clique para editar',
///     done: 'Concluir edição',
///     commands: {
///       MarkdownCommand.bold: 'Negrito',
///       MarkdownCommand.italic: 'Itálico',
///     },
///   ),
///   onEditingComplete: _save,
/// )
/// ```
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.labels,
    this.enabled = true,
    this.startInEdit = false,
    this.minHeight = 96,
    this.minLines = 4,
    this.onChanged,
    this.onEditingComplete,
  });

  final TextEditingController controller;
  final MarkdownEditorLabels labels;
  final bool enabled;

  /// Abre já no texto puro, sem exigir o clique no conteúdo renderizado.
  final bool startInEdit;

  /// Altura mínima da área renderizada.
  final double minHeight;

  /// Linhas mínimas do texto puro durante a edição.
  final int minLines;

  final ValueChanged<String>? onChanged;

  /// Chamado ao sair da edição, apenas quando o texto mudou.
  final ValueChanged<String>? onEditingComplete;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;
  String _textOnEditStart = '';

  TextEditingController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
    if (widget.startInEdit) {
      _isEditing = true;
      _textOnEditStart = _controller.text;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isEditing) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus && _isEditing) {
      _finishEditing();
    }
  }

  void _startEditing() {
    if (!widget.enabled || _isEditing) {
      return;
    }
    _textOnEditStart = _controller.text;
    setState(() => _isEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isEditing) {
        _focusNode.requestFocus();
      }
    });
  }

  void _finishEditing() {
    if (!_isEditing) {
      return;
    }
    final text = _controller.text;
    setState(() => _isEditing = false);
    _focusNode.unfocus();
    if (text != _textOnEditStart) {
      _textOnEditStart = text;
      widget.onEditingComplete?.call(text);
    }
  }

  /// Executa o comando no texto atual e devolve o cursor para o fim da edição.
  void _apply(MarkdownCommand command) {
    final value = _controller.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final selected = text.substring(start, end);

    final prefix = _linePrefixOf(command);
    if (prefix != null) {
      final lineStart = text.lastIndexOf('\n', start == 0 ? 0 : start - 1) + 1;
      final updated = text.replaceRange(lineStart, lineStart, prefix);
      _setText(
        updated,
        selectionStart: start + prefix.length,
        selectionEnd: end + prefix.length,
      );
    } else {
      final (replacement, cursorOffset) = _inlineReplacement(command, selected);
      final updated = text.replaceRange(start, end, replacement);
      _setText(
        updated,
        selectionStart: start + cursorOffset,
        selectionEnd: start + cursorOffset,
      );
    }
    _focusNode.requestFocus();
  }

  void _setText(
    String text, {
    required int selectionStart,
    required int selectionEnd,
  }) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: selectionStart,
        extentOffset: selectionEnd,
      ),
    );
    widget.onChanged?.call(text);
  }

  static String? _linePrefixOf(MarkdownCommand command) {
    return switch (command) {
      MarkdownCommand.heading => '# ',
      MarkdownCommand.bulletList => '- ',
      MarkdownCommand.checklist => '- [ ] ',
      MarkdownCommand.quote => '> ',
      _ => null,
    };
  }

  (String, int) _inlineReplacement(MarkdownCommand command, String selected) {
    switch (command) {
      case MarkdownCommand.bold:
        return _inline(selected, '**', '**', placeholder: 'negrito');
      case MarkdownCommand.italic:
        return _inline(selected, '*', '*', placeholder: 'itálico');
      case MarkdownCommand.code:
        return _inline(selected, '`', '`', placeholder: 'código');
      case MarkdownCommand.link:
        if (selected.isEmpty) {
          return ('[texto](https://)', 8);
        }
        return ('[$selected](https://)', selected.length + 3);
      case MarkdownCommand.heading:
      case MarkdownCommand.bulletList:
      case MarkdownCommand.checklist:
      case MarkdownCommand.quote:
        return (selected, 0);
    }
  }

  (String, int) _inline(
    String selected,
    String before,
    String after, {
    required String placeholder,
  }) {
    final content = selected.isEmpty ? placeholder : selected;
    final replacement = '$before$content$after';
    final cursor = selected.isEmpty
        ? before.length + content.length
        : replacement.length;
    return (replacement, cursor);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final labels = widget.labels;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (labels.label != null) ...[
              Text(
                labels.label!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            if (_isEditing) _buildEditor(context) else _buildReading(context),
          ],
        );
      },
    );
  }

  Widget _buildReading(BuildContext context) {
    final labels = widget.labels;

    return Semantics(
      button: widget.enabled,
      label: labels.edit,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: widget.enabled ? _startEditing : null,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: widget.minHeight),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: MarkdownText(_controller.text, emptyText: labels.emptyPreview),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final labels = widget.labels;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final text = _controller.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labels.commands.isNotEmpty)
          Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final command in MarkdownCommand.values)
                  if (labels.commands.containsKey(command))
                    IconButton(
                      tooltip: labels.commands[command],
                      onPressed: widget.enabled ? () => _apply(command) : null,
                      icon: Icon(_iconOf(command), size: AppSpacing.iconSize),
                    ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          minLines: widget.minLines,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textAlignVertical: TextAlignVertical.top,
          style: textTheme.bodyMedium,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: labels.hint,
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            if (labels.countLabel != null)
              Expanded(
                child: Text(
                  labels.countLabel!(
                    text.length,
                    text.trim().isEmpty
                        ? 0
                        : text.trim().split(RegExp(r'\s+')).length,
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              const Spacer(),
            TextButton.icon(
              onPressed: _finishEditing,
              icon: const Icon(Icons.check_rounded, size: AppSpacing.iconSize),
              label: Text(labels.done),
            ),
          ],
        ),
      ],
    );
  }

  static IconData _iconOf(MarkdownCommand command) {
    return switch (command) {
      MarkdownCommand.heading => Icons.title_rounded,
      MarkdownCommand.bold => Icons.format_bold_rounded,
      MarkdownCommand.italic => Icons.format_italic_rounded,
      MarkdownCommand.bulletList => Icons.format_list_bulleted_rounded,
      MarkdownCommand.checklist => Icons.checklist_rounded,
      MarkdownCommand.quote => Icons.format_quote_rounded,
      MarkdownCommand.code => Icons.code_rounded,
      MarkdownCommand.link => Icons.link_rounded,
    };
  }
}
