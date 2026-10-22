import 'package:flutter/foundation.dart';

import '../../../core/domain/sensitivity_level.dart';
import '../../../core/network/api_exception.dart';
import '../data/agenda_repository.dart';
import '../domain/agenda_models.dart';

class AgendaController extends ChangeNotifier {
  AgendaController(this._dataSource, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final now = _clock();
    _year = now.year;
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  final AgendaDataSource _dataSource;
  final DateTime Function() _clock;

  final Map<int, Map<String, AgendaDaySummary>> _summariesByYear = {};
  final Map<String, AgendaDay> _previewDays = {};
  final Set<String> _loadingPreviews = {};
  late int _year;
  late DateTime _selectedDay;
  AgendaDay? _day;
  bool _isLoadingYear = false;
  bool _isLoadingDay = false;
  bool _isSavingNote = false;
  bool _isSavingDaySensitivity = false;
  bool _isSavingActivity = false;
  bool _isSavingTags = false;
  int? _busyActivityId;
  ApiException? _yearError;
  ApiException? _dayError;

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get selectedDay => _selectedDay;
  int get year => _year;
  AgendaDay? get day => _day;
  bool get isLoadingYear => _isLoadingYear;
  bool get isLoadingDay => _isLoadingDay;
  bool get isSavingNote => _isSavingNote;
  bool get isSavingDaySensitivity => _isSavingDaySensitivity;
  bool get isSavingActivity => _isSavingActivity;
  bool get isSavingTags => _isSavingTags;
  bool isBusyActivity(int activityId) => _busyActivityId == activityId;
  ApiException? get yearError => _yearError;
  ApiException? get dayError => _dayError;

  /// Dia já carregado para a prévia no calendário; nulo até a primeira leitura.
  AgendaDay? previewDay(DateTime day) => _previewDays[dateKey(day)];
  bool isLoadingPreview(DateTime day) =>
      _loadingPreviews.contains(dateKey(day));

  Map<String, AgendaDaySummary> get summaries => summariesForYear(_year);
  Map<String, AgendaDaySummary> summariesForYear(int year) =>
      _summariesByYear[year] ?? const {};
  bool get isYearLoaded => isYearLoadedFor(_year);
  bool isYearLoadedFor(int year) => _summariesByYear.containsKey(year);

  AgendaDaySummary? summaryFor(DateTime day) =>
      _summariesByYear[day.year]?[dateKey(day)];

  Future<void> initialize() async {
    await Future.wait([loadYear(_year), _loadDay()]);
  }

  Future<void> loadYear(int year, {bool force = false}) async {
    _year = year;
    if (!force && _summariesByYear.containsKey(year)) {
      notifyListeners();
      return;
    }

    _isLoadingYear = true;
    _yearError = null;
    notifyListeners();

    try {
      final summaries = await _dataSource.fetchSummaries(
        from: DateTime(year, 1, 1),
        to: DateTime(year, 12, 31),
      );
      if (_year == year) {
        _summariesByYear[year] = {
          for (final summary in summaries) dateKey(summary.day): summary,
        };
      }
    } on ApiException catch (error) {
      _yearError = error;
    } finally {
      _isLoadingYear = false;
      notifyListeners();
    }
  }

  Future<void> selectDay(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);

    if (isSameDay(normalized, _selectedDay) && _day != null) {
      notifyListeners();
      return;
    }

    _selectedDay = normalized;
    _day = null;
    _dayError = null;
    notifyListeners();
    await _loadDay();
  }

  Future<void> goToToday() async {
    if (today.year != _year) {
      await loadYear(today.year);
    }
    await selectDay(today);
  }

  Future<void> refresh() async {
    await Future.wait([loadYear(_year, force: true), _loadDay()]);
  }

  Future<ApiException?> addNote(
    String content, {
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    if (_isSavingNote) {
      return null;
    }

    _isSavingNote = true;
    notifyListeners();
    try {
      await _dataSource.addNote(
        _selectedDay,
        content,
        sensitivity: sensitivity,
      );
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isSavingNote = false;
      notifyListeners();
    }
  }

  Future<ApiException?> updateNote(
    int noteId, {
    String? content,
    SensitivityLevel? sensitivity,
  }) async {
    if (_isSavingNote) {
      return null;
    }

    _isSavingNote = true;
    notifyListeners();
    try {
      await _dataSource.updateNote(
        noteId,
        content: content,
        sensitivity: sensitivity,
      );
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isSavingNote = false;
      notifyListeners();
    }
  }

  Future<ApiException?> deleteNote(int noteId) async {
    if (_isSavingNote) {
      return null;
    }

    _isSavingNote = true;
    notifyListeners();
    try {
      await _dataSource.deleteNote(noteId);
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isSavingNote = false;
      notifyListeners();
    }
  }

  Future<ApiException?> setDaySensitivity(SensitivityLevel sensitivity) async {
    if (_isSavingDaySensitivity) {
      return null;
    }

    _isSavingDaySensitivity = true;
    notifyListeners();
    try {
      await _dataSource.setDaySensitivity(_selectedDay, sensitivity);
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isSavingDaySensitivity = false;
      notifyListeners();
    }
  }

  /// Carrega o dia para a prévia do calendário, uma vez por dia.
  Future<void> loadPreview(DateTime day) async {
    final key = dateKey(day);
    if (_previewDays.containsKey(key) || _loadingPreviews.contains(key)) {
      return;
    }

    _loadingPreviews.add(key);
    notifyListeners();
    try {
      _previewDays[key] = await _dataSource.fetchDay(day);
    } on ApiException {
      // A prévia é apoio: sem dados, o calendário segue com o resumo da marca.
    } finally {
      _loadingPreviews.remove(key);
      notifyListeners();
    }
  }

  Future<ApiException?> addActivity({
    required String title,
    String? startTime,
    required AgendaPriority priority,
    SensitivityLevel sensitivity = SensitivityLevel.publico,
  }) async {
    if (_isSavingActivity) {
      return null;
    }

    _isSavingActivity = true;
    notifyListeners();
    try {
      await _dataSource.createActivity(
        day: _selectedDay,
        title: title,
        startTime: startTime,
        priority: priority,
        sensitivity: sensitivity,
      );
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isSavingActivity = false;
      notifyListeners();
    }
  }

  Future<ApiException?> toggleActivity(AgendaActivity activity) async {
    if (_busyActivityId != null) {
      return null;
    }

    _busyActivityId = activity.id;
    notifyListeners();
    try {
      await _dataSource.updateActivity(activity.id, isDone: !activity.isDone);
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _busyActivityId = null;
      notifyListeners();
    }
  }

  Future<ApiException?> deleteActivity(int activityId) async {
    if (_busyActivityId != null) {
      return null;
    }

    _busyActivityId = activityId;
    notifyListeners();
    try {
      await _dataSource.deleteActivity(activityId);
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _busyActivityId = null;
      notifyListeners();
    }
  }

  Future<ApiException?> setActivitySensitivity(
    AgendaActivity activity,
    SensitivityLevel sensitivity,
  ) async {
    if (_busyActivityId != null) {
      return null;
    }

    _busyActivityId = activity.id;
    notifyListeners();
    try {
      await _dataSource.updateActivity(activity.id, sensitivity: sensitivity);
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _busyActivityId = null;
      notifyListeners();
    }
  }

  Future<ApiException?> setDayTags(List<int> tagIds) async {
    if (_isSavingTags) {
      return null;
    }

    _isSavingTags = true;
    notifyListeners();
    try {
      await _dataSource.setDayTags(_selectedDay, tagIds);
      await _reloadAfterChange();
      return null;
    } on ApiException catch (error) {
      return error;
    } finally {
      _isSavingTags = false;
      notifyListeners();
    }
  }

  Future<void> _loadDay() async {
    final requested = _selectedDay;
    _isLoadingDay = true;
    _dayError = null;
    notifyListeners();

    try {
      final day = await _dataSource.fetchDay(requested);
      if (isSameDay(day.day, _selectedDay)) {
        _day = day;
        _previewDays[dateKey(day.day)] = day;
      }
    } on ApiException catch (error) {
      _dayError = error;
    } finally {
      _isLoadingDay = false;
      notifyListeners();
    }
  }

  Future<void> _reloadAfterChange() async {
    _previewDays.remove(dateKey(_selectedDay));
    await _loadDay();
    await Future.wait(
      {_selectedDay.year, _year}.map((year) => _refreshYear(year)),
    );
  }

  Future<void> _refreshYear(int year) async {
    try {
      final summaries = await _dataSource.fetchSummaries(
        from: DateTime(year, 1, 1),
        to: DateTime(year, 12, 31),
      );
      _summariesByYear[year] = {
        for (final summary in summaries) dateKey(summary.day): summary,
      };
    } on ApiException {
      // A alteração já foi aplicada; mantém os resumos anteriores.
    }
    notifyListeners();
  }
}
