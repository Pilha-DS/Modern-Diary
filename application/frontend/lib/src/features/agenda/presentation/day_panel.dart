import 'package:flutter/material.dart';
import 'package:atena_ui/atena_ui.dart' hide SensitivityBadge, SensitivitySelector;

import '../../../core/presentation/sensitivity_selector.dart';
import '../../../core/strings/app_strings.dart';
import '../../home/presentation/home_navigation.dart';
import '../../tags/data/tags_repository.dart';
import '../../tags/domain/tag_models.dart';
import '../../tags/presentation/tag_chips.dart';
import '../../tags/presentation/tag_picker.dart';
import '../domain/agenda_models.dart';
import 'activity_tile.dart';
import 'agenda_controller.dart';
import 'calendar_marks.dart';

/// Conteúdo do dia: nível e tags, notas e atividades.
///
/// A leitura é o padrão: o dia só muda depois que o usuário toca em "Editar".
/// Nesse modo aparecem as ações de criar/editar nota, escolher o nível de cada
/// nota e de cada atividade, adicionar tag e criar/remover atividade.
class DayPanel extends StatefulWidget {
  const DayPanel({
    super.key,
    required this.controller,
    required this.tagsDataSource,
    required this.toat,
    this.navigation,
    this.embedded = false,
  });

  final AgendaController controller;
  final TagsDataSource tagsDataSource;
  final ToatController toat;

  /// Leva a tag clicada até o menu de tags.
  final HomeNavigation? navigation;

  /// Sem superfície e sem cabeçalho próprios, para ser exibido dentro de um
  /// modal que já traz o título do dia.
  final bool embedded;

  @override
  State<DayPanel> createState() => _DayPanelState();
}

class _DayPanelState extends State<DayPanel> {
  bool _editing = false;
  bool _levelInitialized = false;
  SensitivityLevel _daySensitivity = SensitivityLevel.publico;
  String? _loadedDayKey;

  AgendaController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final day = _controller.day;
        _ensureDayState(day);

        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded) ...[
              _buildHeader(context),
              const SizedBox(height: AppSpacing.sm),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: _buildEditButton(),
              ),
            if (_controller.isLoadingDay && day == null)
              const StatusView.loading(title: AppStrings.agendaDayLoading)
            else if (day == null && _controller.dayError != null)
              StatusView.error(
                title: AppStrings.agendaDayErrorTitle,
                message: _controller.dayError!.message,
                actionLabel: AppStrings.retry,
                onAction: _controller.refresh,
              )
            else if (day != null) ...[
              if (_controller.dayError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: InlineMessage(
                    message: _controller.dayError!.message,
                    variant: InlineMessageVariant.error,
                  ),
                ),
              if (day.holiday != null) ...[
                _buildHoliday(day.holiday!),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildDayMeta(context, day),
              const SizedBox(height: AppSpacing.lg),
              _buildNotes(context, day),
              const SizedBox(height: AppSpacing.lg),
              _buildActivities(context, day),
            ],
          ],
        );

        if (widget.embedded) {
          return content;
        }
        return AppSurface(child: content);
      },
    );
  }

  /// Inicializa o nível e o modo ao trocar de dia; o nível só é copiado depois
  /// que o dia chega, para não fixar o padrão enquanto carrega.
  void _ensureDayState(AgendaDay? day) {
    final key = dateKey(_controller.selectedDay);
    if (key != _loadedDayKey) {
      _loadedDayKey = key;
      _editing = false;
      _levelInitialized = false;
    }
    if (!_levelInitialized && day != null) {
      _daySensitivity = day.sensitivity ?? SensitivityLevel.publico;
      _levelInitialized = true;
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            AppStrings.dayTitle(_controller.selectedDay),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: AppStrings.refresh,
          onPressed: _controller.isLoadingDay ? null : _controller.refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildEditButton(),
      ],
    );
  }

  Widget _buildEditButton() {
    return AppButton(
      label: _editing ? AppStrings.finishDayEditing : AppStrings.editDay,
      icon: _editing ? Icons.check_rounded : Icons.edit_outlined,
      variant: _editing ? AppButtonVariant.primary : AppButtonVariant.secondary,
      onPressed: () => setState(() => _editing = !_editing),
    );
  }

  /// Status do dia: feriado não é nota nem atividade, então aparece sozinho,
  /// com o laranja que o calendário usa para o mesmo dia.
  Widget _buildHoliday(String name) {
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = AppSemanticColors.of(context);

    return Semantics(
      container: true,
      label: AppStrings.holidayStatus(name),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: semanticColors.holidaySoft,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            Icon(
              Icons.celebration_outlined,
              size: AppSpacing.iconSize,
              color: semanticColors.holiday,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                AppStrings.holidayStatus(name),
                style: textTheme.bodyMedium?.copyWith(
                  color: semanticColors.holiday,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayMeta(BuildContext context, AgendaDay day) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (!_editing) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (day.sensitivity != null)
            SensitivityBadge(level: day.sensitivity!)
          else
            AppChip(
              icon: Icons.shield_outlined,
              label: AppStrings.daySensitivityNone,
            ),
          TagChips(
            tags: day.tags,
            onTap: widget.navigation == null ? null : _openTag,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SensitivitySelector(
          label: AppStrings.daySensitivityLabel,
          selected: _daySensitivity,
          onChanged: _changeDaySensitivity,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(AppStrings.dayTagsTitle, style: textTheme.titleSmall),
            ),
            TextButton.icon(
              onPressed: _controller.isSavingTags ? null : () => _editTags(day),
              icon: const Icon(Icons.sell_outlined, size: AppSpacing.iconSize),
              label: const Text(AppStrings.tagPickerAdd),
            ),
          ],
        ),
        if (day.tags.isEmpty)
          Text(
            AppStrings.dayTagsEmpty,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          TagChips(
            tags: day.tags,
            onTap: widget.navigation == null ? null : _openTag,
            onRemove: _controller.isSavingTags
                ? null
                : (tag) {
                    final remaining = [
                      for (final kept in day.tags)
                        if (kept.id != tag.id) kept.id,
                    ];
                    _setTags(remaining);
                  },
          ),
      ],
    );
  }

  Widget _buildNotes(BuildContext context, AgendaDay day) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Text(AppStrings.noteTitle, style: textTheme.titleSmall),
            if (_editing)
              AppButton(
                label: AppStrings.newNote,
                icon: Icons.add_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: _controller.isSavingNote ? null : _addNote,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (day.notes.isEmpty)
          Text(
            AppStrings.noteEmpty,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (var index = 0; index < day.notes.length; index++) ...[
            _NoteCard(
              note: day.notes[index],
              index: index + 1,
              editing: _editing,
              busy: _controller.isSavingNote,
              onEdit: () => _editNote(day.notes[index]),
              onDelete: () => _deleteNote(day.notes[index]),
            ),
            if (index != day.notes.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  Widget _buildActivities(BuildContext context, AgendaDay day) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppStrings.activitiesTitle, style: textTheme.titleSmall),
                if (day.activities.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.activitiesCount(
                      day.doneCount,
                      day.activities.length,
                    ),
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            if (_editing)
              AppButton(
                label: AppStrings.newActivity,
                icon: Icons.add_rounded,
                variant: AppButtonVariant.secondary,
                onPressed: _controller.isSavingActivity ? null : _addActivity,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (day.activities.isEmpty)
          const StatusView.empty(
            icon: Icons.event_available_outlined,
            title: AppStrings.activitiesEmptyTitle,
            message: AppStrings.activitiesEmptyMessage,
          )
        else
          for (final activity in day.activities)
            _editing
                ? ActivityTile(
                    title: activity.title,
                    timeLabel: activity.startTime,
                    sensitivityLabel: AppStrings.sensitivityLabelOf(
                      activity.sensitivity.apiValue,
                    ),
                    sensitivityActionLabel:
                        AppStrings.activitySensitivityAction,
                    priority: activityPriority(activity.priority),
                    priorityLabel: priorityLabel(activity.priority),
                    isDone: activity.isDone,
                    isBusy: _controller.isBusyActivity(activity.id),
                    toggleLabel: activity.isDone
                        ? AppStrings.activityMarkPending
                        : AppStrings.activityMarkDone,
                    deleteLabel: AppStrings.activityDeleteAction,
                    onToggle: () => _toggleActivity(activity),
                    onDelete: () => _deleteActivity(activity),
                    onSensitivityPressed: () =>
                        _editActivitySensitivity(activity),
                  )
                : _ReadActivityRow(activity: activity),
      ],
    );
  }

  void _openTag(Tag tag) {
    final navigation = widget.navigation;
    if (navigation == null) {
      return;
    }
    if (widget.embedded) {
      Navigator.of(context).maybePop();
    }
    navigation.openTag(tag);
  }

  Future<void> _changeDaySensitivity(SensitivityLevel level) async {
    if (level == _daySensitivity || _controller.isSavingDaySensitivity) {
      return;
    }
    final error = await _controller.setDaySensitivity(level);
    if (!mounted) {
      return;
    }
    if (error == null) {
      setState(() => _daySensitivity = level);
      widget.toat.show(
        AppStrings.daySensitivitySaved,
        variant: ToatVariant.success,
      );
    } else {
      setState(
        () => _daySensitivity =
            _controller.day?.sensitivity ?? SensitivityLevel.publico,
      );
      widget.toat.show(error.message, variant: ToatVariant.error);
    }
  }

  Future<void> _addNote() async {
    final draft = await showAppDialog<_NoteDraft>(
      context,
      title: AppStrings.newNote,
      closeLabel: AppStrings.close,
      child: const _NoteForm(),
    );
    if (draft == null || !mounted) {
      return;
    }

    final error = await _controller.addNote(
      draft.content,
      sensitivity: draft.sensitivity,
    );
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? AppStrings.dayNoteCreated,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  Future<void> _editNote(AgendaNote note) async {
    final draft = await showAppDialog<_NoteDraft>(
      context,
      title: AppStrings.editNote,
      closeLabel: AppStrings.close,
      child: _NoteForm(note: note),
    );
    if (draft == null || !mounted) {
      return;
    }

    final error = await _controller.updateNote(
      note.id,
      content: draft.content,
      sensitivity: draft.sensitivity,
    );
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? AppStrings.dayNoteUpdated,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  Future<void> _deleteNote(AgendaNote note) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.dayNoteDeleteTitle,
      message: AppStrings.dayNoteDeleteMessage,
      confirmLabel: AppStrings.delete,
      cancelLabel: AppStrings.cancel,
    );
    if (!confirmed) {
      return;
    }

    final error = await _controller.deleteNote(note.id);
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? AppStrings.dayNoteDeleted,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  Future<void> _editTags(AgendaDay day) async {
    final picked = await showTagPicker(
      context,
      dataSource: widget.tagsDataSource,
      selected: day.tags,
    );
    if (picked == null || !mounted) {
      return;
    }
    await _setTags([for (final tag in picked) tag.id]);
  }

  Future<void> _setTags(List<int> tagIds) async {
    final error = await _controller.setDayTags(tagIds);
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? AppStrings.dayTagsSaved,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  Future<void> _toggleActivity(AgendaActivity activity) async {
    final error = await _controller.toggleActivity(activity);
    if (error != null && mounted) {
      widget.toat.show(error.message, variant: ToatVariant.error);
    }
  }

  Future<void> _deleteActivity(AgendaActivity activity) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: AppStrings.activityDeleteTitle,
      message: AppStrings.activityDeleteMessage(activity.title),
      confirmLabel: AppStrings.delete,
      cancelLabel: AppStrings.cancel,
    );
    if (!confirmed) {
      return;
    }

    final error = await _controller.deleteActivity(activity.id);
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? AppStrings.activityDeleted,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  Future<void> _editActivitySensitivity(AgendaActivity activity) async {
    final level = await _pickLevel(
      AppStrings.activitySensitivityAction,
      activity.sensitivity,
    );
    if (level == null || level == activity.sensitivity || !mounted) {
      return;
    }

    final error = await _controller.setActivitySensitivity(activity, level);
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? AppStrings.activitySensitivitySaved,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }

  Future<SensitivityLevel?> _pickLevel(String title, SensitivityLevel initial) {
    var selected = initial;
    return showAppDialog<SensitivityLevel>(
      context,
      title: title,
      closeLabel: AppStrings.close,
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SensitivitySelector(
              label: title,
              selected: selected,
              onChanged: (level) => setDialogState(() => selected = level),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: AppStrings.confirmSelection,
                onPressed: () => Navigator.of(dialogContext).pop(selected),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addActivity() async {
    final draft = await showDialog<_ActivityDraft>(
      context: context,
      builder: (context) => const _AddActivityDialog(),
    );
    if (draft == null) {
      return;
    }

    final error = await _controller.addActivity(
      title: draft.title,
      startTime: draft.startTime,
      priority: draft.priority,
      sensitivity: draft.sensitivity,
    );
    if (!mounted) {
      return;
    }
    widget.toat.show(
      error?.message ?? AppStrings.activityCreated,
      variant: error == null ? ToatVariant.success : ToatVariant.error,
    );
  }
}

/// Cartão de uma nota. O conteúdo completo só aparece no clique ou no hover;
/// no modo de edição os botões de editar e excluir ficam no cabeçalho.
class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.note,
    required this.index,
    required this.editing,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final AgendaNote note;
  final int index;
  final bool editing;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _expanded = false;
  bool _hovered = false;

  bool get _showContent => _expanded || _hovered || widget.editing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final header = Row(
      children: [
        Text(
          AppStrings.noteIndex(widget.index),
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: AppSpacing.sm),
        SensitivityBadge(level: widget.note.sensitivity),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            AppStrings.noteWords(_wordCount(widget.note.content)),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (widget.editing) ...[
          IconButton(
            tooltip: AppStrings.noteEditAction,
            onPressed: widget.busy ? null : widget.onEdit,
            icon: const Icon(Icons.edit_outlined, size: AppSpacing.iconSize),
          ),
          IconButton(
            tooltip: AppStrings.delete,
            onPressed: widget.busy ? null : widget.onDelete,
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: AppSpacing.iconSize,
            ),
          ),
        ] else
          Icon(
            _showContent
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            size: AppSpacing.iconSize,
            color: colorScheme.onSurfaceVariant,
          ),
      ],
    );

    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: !widget.editing,
            label: _showContent
                ? AppStrings.noteCollapse
                : AppStrings.noteExpand,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              onTap: widget.editing
                  ? null
                  : () => setState(() => _expanded = !_expanded),
              child: header,
            ),
          ),
          if (_showContent) ...[
            const SizedBox(height: AppSpacing.sm),
            MarkdownText(widget.note.content),
          ],
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) {
        if (!widget.editing) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) {
        if (_hovered) {
          setState(() => _hovered = false);
        }
      },
      child: card,
    );
  }

  int _wordCount(String content) {
    final trimmed = content.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }
}

/// Linha de leitura de uma atividade: só o estado, o título e o horário.
class _ReadActivityRow extends StatelessWidget {
  const _ReadActivityRow({required this.activity});

  final AgendaActivity activity;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = AppSemanticColors.of(context);

    return Semantics(
      label: activity.title,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(
              activity.isDone
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: AppSpacing.iconSize,
              color: activity.isDone
                  ? semanticColors.brandDeep
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                activity.title,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: activity.isDone
                      ? TextDecoration.lineThrough
                      : null,
                  color: activity.isDone ? colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
            if (activity.startTime != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                activity.startTime!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteDraft {
  const _NoteDraft({required this.content, required this.sensitivity});

  final String content;
  final SensitivityLevel sensitivity;
}

class _NoteForm extends StatefulWidget {
  const _NoteForm({this.note});

  final AgendaNote? note;

  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  late final TextEditingController _contentController;
  late SensitivityLevel _sensitivity;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _sensitivity = widget.note?.sensitivity ?? SensitivityLevel.publico;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      setState(() => _error = AppStrings.dayNoteContentRequired);
      return;
    }
    Navigator.of(context)
        .pop(_NoteDraft(content: content, sensitivity: _sensitivity));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownEditor(
          controller: _contentController,
          startInEdit: true,
          minLines: 6,
          labels: MarkdownEditorLabels(
            hint: AppStrings.noteHint,
            emptyPreview: AppStrings.noteHint,
            edit: AppStrings.markdownEdit,
            done: AppStrings.markdownDone,
            commands: const {
              MarkdownCommand.heading: AppStrings.noteToolbarHeading,
              MarkdownCommand.bold: AppStrings.noteToolbarBold,
              MarkdownCommand.italic: AppStrings.noteToolbarItalic,
              MarkdownCommand.bulletList: AppStrings.noteToolbarList,
              MarkdownCommand.checklist: AppStrings.noteToolbarChecklist,
              MarkdownCommand.quote: AppStrings.noteToolbarQuote,
              MarkdownCommand.code: AppStrings.noteToolbarCode,
              MarkdownCommand.link: AppStrings.noteToolbarLink,
            },
            countLabel: AppStrings.noteCount,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error!,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SensitivitySelector(
          label: AppStrings.sensitivityNoteLabel,
          selected: _sensitivity,
          onChanged: (level) => setState(() => _sensitivity = level),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(label: AppStrings.saveNote, onPressed: _submit),
        ),
      ],
    );
  }
}

class _ActivityDraft {
  const _ActivityDraft({
    required this.title,
    required this.priority,
    required this.sensitivity,
    this.startTime,
  });

  final String title;
  final String? startTime;
  final AgendaPriority priority;
  final SensitivityLevel sensitivity;
}

class _AddActivityDialog extends StatefulWidget {
  const _AddActivityDialog();

  @override
  State<_AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<_AddActivityDialog> {
  final _titleController = TextEditingController();
  AgendaPriority _priority = AgendaPriority.medium;
  SensitivityLevel _sensitivity = SensitivityLevel.publico;
  TimeOfDay? _time;
  String? _titleError;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// Horário no formato 24 h que o back recebe (`09:30`).
  String get _formattedTime {
    final time = _time;
    if (time == null) {
      return '';
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// A hora não é digitada: o relógio de órbitas define horas e minutos.
  Future<void> _pickTime() async {
    final picked = await showAppTimePicker(
      context,
      title: AppStrings.timePickerTitle,
      hoursLabel: AppStrings.timePickerHours,
      minutesLabel: AppStrings.timePickerMinutes,
      cancelLabel: AppStrings.cancel,
      confirmLabel: AppStrings.timePickerConfirm,
      closeLabel: AppStrings.close,
      initial: _time,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _time = picked);
  }

  void _submit() {
    final title = _titleController.text.trim();

    setState(() {
      _titleError = title.isEmpty ? AppStrings.activityTitleRequired : null;
    });

    if (_titleError != null) {
      return;
    }

    Navigator.of(context).pop(
      _ActivityDraft(
        title: title,
        startTime: _time == null ? null : _formattedTime,
        priority: _priority,
        sensitivity: _sensitivity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text(AppStrings.newActivity),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: AppStrings.activityTitleLabel,
                  hintText: AppStrings.activityTitleHint,
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTimeField(
                label: AppStrings.activityTimeLabel,
                placeholder: AppStrings.activityTimePlaceholder,
                value: _time == null ? null : _formattedTime,
                onPressed: _pickTime,
                clearLabel: AppStrings.activityTimeClear,
                onClear: () => setState(() => _time = null),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.priorityLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  for (final priority in AgendaPriority.values) ...[
                    Expanded(
                      child: AppButton(
                        label: priorityLabel(priority),
                        variant: _priority == priority
                            ? AppButtonVariant.primary
                            : AppButtonVariant.secondary,
                        onPressed: () => setState(() => _priority = priority),
                      ),
                    ),
                    if (priority != AgendaPriority.values.last)
                      const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SensitivitySelector(
                label: AppStrings.sensitivityActivityLabel,
                selected: _sensitivity,
                onChanged: (level) => setState(() => _sensitivity = level),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.cancel),
        ),
        AppButton(label: AppStrings.createActivity, onPressed: _submit),
      ],
    );
  }
}
