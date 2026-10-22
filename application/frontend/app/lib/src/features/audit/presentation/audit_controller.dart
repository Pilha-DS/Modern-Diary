import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/audit_repository.dart';
import '../domain/audit_models.dart';

/// Dia e mês em foco na auditoria, com o histórico e o grafo do dia.
class AuditController extends ChangeNotifier {
  AuditController(this._dataSource, {DateTime? today})
    : _today = _normalize(today ?? DateTime.now()) {
    _month = DateTime(_today.year, _today.month);
    _selectedDay = _today;
  }

  final AuditDataSource _dataSource;
  final DateTime _today;

  static const int pageSize = 20;

  late DateTime _month;
  late DateTime _selectedDay;
  List<AuditDaySummary> _days = const [];
  List<AuditEvent> _events = const [];
  AuditGraphData _graph = const AuditGraphData();
  int _page = 0;
  int _total = 0;
  int _totalPages = 0;
  bool _isLoadingDay = false;
  bool _isLoadingMore = false;
  bool _isFetching = false;
  bool _initialized = false;
  int _requestId = 0;
  ApiException? _error;

  DateTime get today => _today;
  DateTime get month => _month;
  DateTime get selectedDay => _selectedDay;
  List<AuditDaySummary> get days => _days;
  List<AuditEvent> get events => _events;
  AuditGraphData get graph => _graph;
  int get total => _total;
  int get perPage => pageSize;
  bool get isLoading => !_initialized || _isLoadingDay;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _page < _totalPages;
  ApiException? get error => _error;

  /// Ações por dia do mês em foco, indexadas pelo número do dia.
  Map<int, AuditDaySummary> get daysOfMonth {
    return {
      for (final entry in _days)
        if (entry.day.year == _month.year && entry.day.month == _month.month)
          entry.day.day: entry,
    };
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await Future.wait([_loadMonth(), _loadDay(showLoading: true)]);
  }

  Future<void> selectDay(DateTime day) async {
    final normalized = _normalize(day);
    if (_sameDay(normalized, _selectedDay)) {
      return;
    }
    _selectedDay = normalized;
    final monthChanged =
        normalized.year != _month.year || normalized.month != _month.month;
    if (monthChanged) {
      _month = DateTime(normalized.year, normalized.month);
    }
    if (monthChanged) {
      await Future.wait([_loadMonth(), _loadDay(showLoading: true)]);
    } else {
      await _loadDay(showLoading: true);
    }
  }

  /// Troca o mês em foco e abre o dia 1 (ou hoje, quando é o mês atual).
  Future<void> moveMonth(int months) async {
    final month = DateTime(_month.year, _month.month + months);
    _month = month;
    _selectedDay = month.year == _today.year && month.month == _today.month
        ? _today
        : DateTime(month.year, month.month);
    await Future.wait([_loadMonth(), _loadDay(showLoading: true)]);
  }

  Future<void> refresh() async {
    await Future.wait([_loadMonth(), _loadDay(showLoading: false)]);
  }

  Future<void> loadMore() async {
    if (_isLoadingDay || _isLoadingMore || _isFetching || !hasMore) {
      return;
    }

    _isLoadingMore = true;
    notifyListeners();
    final requestId = _requestId;
    try {
      final page = await _dataSource.fetchDay(
        _selectedDay,
        page: _page + 1,
        perPage: pageSize,
      );
      if (requestId != _requestId) {
        return;
      }
      _events = [..._events, ...page.items];
      _applyPage(page);
    } on ApiException catch (error) {
      if (requestId != _requestId) {
        return;
      }
      _error = error;
    } finally {
      if (requestId == _requestId) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadMonth() async {
    final first = DateTime(_month.year, _month.month);
    final last = DateTime(_month.year, _month.month + 1, 0);
    try {
      _days = await _dataSource.fetchDays(from: first, to: last);
    } on ApiException catch (error) {
      _days = const [];
      _error = error;
    }
    notifyListeners();
  }

  Future<void> _loadDay({required bool showLoading}) async {
    // Cada dia ganha um identificador: a resposta de um dia antigo não pode
    // sobrescrever o dia que o usuário abriu depois.
    final requestId = ++_requestId;
    _isFetching = true;
    _isLoadingMore = false;
    if (showLoading) {
      _isLoadingDay = true;
    }
    _error = null;
    notifyListeners();

    final day = _selectedDay;
    final pageFuture = _dataSource.fetchDay(day, page: 1, perPage: pageSize);
    final graphFuture = _dataSource.fetchGraph(day);
    try {
      // As duas chamadas andam juntas; `Future.wait` cuida do erro da outra
      // quando uma delas falha, sem deixar exceção solta.
      final results = await Future.wait<Object>([pageFuture, graphFuture]);
      final page = results[0] as AuditEventPage;
      final graph = results[1] as AuditGraphData;
      if (requestId != _requestId) {
        return;
      }
      _events = page.items;
      _graph = graph;
      _applyPage(page);
    } on ApiException catch (error) {
      if (requestId != _requestId) {
        return;
      }
      _events = const [];
      _graph = const AuditGraphData();
      _page = 0;
      _total = 0;
      _totalPages = 0;
      _error = error;
    } finally {
      if (requestId == _requestId) {
        _isFetching = false;
        _isLoadingDay = false;
        notifyListeners();
      }
    }
  }

  void _applyPage(AuditEventPage page) {
    _page = page.page;
    _total = page.total;
    _totalPages = page.totalPages;
  }

  static DateTime _normalize(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
