import 'dart:async';

import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/strings/app_strings.dart';
import '../data/notes_repository.dart';
import '../domain/note_models.dart';
import 'note_card.dart';
import 'note_editor_dialog.dart';
import 'notes_controller.dart';

/// Sistema de notas: busca, filtro, lista de cartões e editor em markdown.
class NotesSection extends StatefulWidget {
  const NotesSection({
    super.key,
    required this.repository,
    required this.toat,
    this.focusNoteId,
    this.onFocusHandled,
  });

  final NotesDataSource repository;
  final ToatController toat;

  /// Nota que outra área pediu para abrir; o pedido é consumido ao abrir.
  final int? focusNoteId;
  final VoidCallback? onFocusHandled;

  @override
  State<NotesSection> createState() => _NotesSectionState();
}

class _NotesSectionState extends State<NotesSection> {
  static const Duration _searchDebounce = Duration(milliseconds: 350);

  late final NotesController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  int? _openingNoteId;

  @override
  void initState() {
    super.initState();
    _controller = NotesController(widget.repository)..loadFirstPage();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
  }

  @override
  void didUpdateWidget(NotesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNoteId != oldWidget.focusNoteId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleFocus());
    }
  }

  void _handleFocus() {
    final noteId = widget.focusNoteId;
    if (noteId == null || !mounted) {
      return;
    }
    widget.onFocusHandled?.call();
    _openNoteById(noteId);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () => _controller.setQuery(value));
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    _controller.setQuery('');
  }

  Future<void> _clearFilters() async {
    _searchTimer?.cancel();
    _searchController.clear();
    await _controller.clearFilters();
  }

  Future<void> _create() async {
    final saved = await showNoteEditorDialog(
      context,
      title: AppStrings.newNote,
      submitLabel: AppStrings.noteCreate,
      onSubmit: (draft) => _controller.createNote(
        title: draft.title,
        content: draft.content,
        sensitivity: draft.sensitivity,
      ),
    );
    if (saved) {
      _notifySuccess(AppStrings.noteCreated);
    }
  }

  Future<void> _edit(NoteSummary summary) => _openNoteById(summary.id);

  Future<void> _openNoteById(int noteId) async {
    if (_openingNoteId != null) {
      return;
    }
    setState(() => _openingNoteId = noteId);
    try {
      final note = await widget.repository.fetchNote(noteId);
      if (!mounted) {
        return;
      }
      setState(() => _openingNoteId = null);
      final saved = await showNoteEditorDialog(
        context,
        title: AppStrings.editNote,
        submitLabel: AppStrings.noteSave,
        note: note,
        onSubmit: (draft) => _controller.updateNote(
          note.id,
          title: draft.title,
          content: draft.content,
          sensitivity: draft.sensitivity,
        ),
      );
      if (saved) {
        _notifySuccess(AppStrings.noteUpdated);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _openingNoteId = null);
        widget.toat.show(error.message, variant: ToatVariant.error);
      }
    }
  }

  Future<void> _delete(NoteSummary summary) async {
    final title = summary.hasTitle ? summary.title! : AppStrings.noteUntitled;
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.noteDeleteTitle,
      message: AppStrings.noteDeleteMessage(title),
      confirmLabel: AppStrings.noteDeleteAction,
      cancelLabel: AppStrings.cancel,
      variant: AppConfirmVariant.warning,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final error = await _controller.deleteNote(summary.id);
    _notify(error, AppStrings.noteDeleted);
  }

  Future<void> _togglePin(NoteSummary summary) async {
    final error = await _controller.togglePin(summary);
    _notify(
      error,
      summary.isPinned ? AppStrings.noteUnpinned : AppStrings.notePinned,
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

  void _notifySuccess(String message) {
    if (!mounted) {
      return;
    }
    widget.toat.show(message, variant: ToatVariant.success);
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
                Text(AppStrings.notesTitle, style: textTheme.titleMedium),
                if (!_controller.isLoading)
                  Text(
                    AppStrings.notesTotal(_controller.total),
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
                  label: AppStrings.newNote,
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
          AppStrings.notesSubtitle,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          onSubmitted: (value) {
            _searchTimer?.cancel();
            _controller.setQuery(value);
          },
          decoration: InputDecoration(
            hintText: AppStrings.noteSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: AppStrings.noteSearchClear,
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            AppChip(
              label: AppStrings.noteFilterAll,
              isSelected: _controller.pinned == null,
              onTap: () => _controller.setPinned(null),
            ),
            AppChip(
              icon: Icons.push_pin_outlined,
              label: AppStrings.noteFilterPinned,
              isSelected: _controller.pinned == true,
              onTap: () => _controller.setPinned(true),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildList(context),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    if (_controller.isLoading) {
      return const StatusView.loading(title: AppStrings.notesLoading);
    }
    if (_controller.error != null && _controller.items.isEmpty) {
      return StatusView.error(
        title: AppStrings.notesErrorTitle,
        message: _controller.error!.message,
        actionLabel: AppStrings.retry,
        onAction: _controller.loadFirstPage,
      );
    }
    if (_controller.items.isEmpty) {
      final isFiltered =
          _controller.query.isNotEmpty || _controller.pinned != null;
      return StatusView.empty(
        icon: Icons.sticky_note_2_outlined,
        title: isFiltered
            ? AppStrings.notesNoResultsTitle
            : AppStrings.notesEmptyTitle,
        message: isFiltered
            ? AppStrings.notesNoResultsMessage
            : AppStrings.notesEmptyMessage,
        actionLabel: isFiltered
            ? AppStrings.noteClearFilters
            : AppStrings.noteCreateFirst,
        onAction: isFiltered ? _clearFilters : _create,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_controller.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: InlineMessage(
              message: _controller.error!.message,
              variant: InlineMessageVariant.error,
            ),
          ),
        AppCardGrid(
          minCardWidth: 220,
          maxColumns: 4,
          children: [
            for (final note in _controller.items)
              NoteCard(
                note: note,
                isBusy:
                    _controller.isBusy(note.id) || _openingNoteId == note.id,
                onOpen: () => _edit(note),
                onEdit: () => _edit(note),
                onDelete: () => _delete(note),
                onTogglePin: () => _togglePin(note),
              ),
          ],
        ),
        if (_controller.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Center(
              child: AppButton(
                label: AppStrings.notesLoadMore,
                variant: AppButtonVariant.secondary,
                isLoading: _controller.isLoadingMore,
                onPressed: _controller.loadMore,
              ),
            ),
          ),
      ],
    );
  }
}
