import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/features/audit/data/audit_repository.dart';
import 'package:modern_diary/src/features/audit/domain/audit_models.dart';

/// Implementação em memória com a mesma regra do back, para testar sem HTTP.
class FakeAuditDataSource implements AuditDataSource {
  FakeAuditDataSource({List<AuditEvent> events = const [], this.error})
    : _events = [...events];

  final List<AuditEvent> _events;
  final ApiException? error;

  int monthCalls = 0;
  int dayCalls = 0;
  int graphCalls = 0;
  DateTime? lastFrom;
  DateTime? lastTo;
  DateTime? lastDay;
  int? lastPage;

  @override
  Future<List<AuditDaySummary>> fetchDays({
    required DateTime from,
    required DateTime to,
  }) async {
    monthCalls++;
    lastFrom = from;
    lastTo = to;
    if (error != null) {
      throw error!;
    }
    final totals = <DateTime, int>{};
    for (final event in _events) {
      final day = _dayOf(event.occurredAt);
      if (day.isBefore(_dayOf(from)) || day.isAfter(_dayOf(to))) {
        continue;
      }
      totals[day] = (totals[day] ?? 0) + 1;
    }
    final days = totals.entries.toList()
      ..sort((first, second) => first.key.compareTo(second.key));
    return [
      for (final entry in days)
        AuditDaySummary(day: entry.key, total: entry.value),
    ];
  }

  @override
  Future<AuditEventPage> fetchDay(
    DateTime day, {
    required int page,
    int? perPage,
  }) async {
    dayCalls++;
    lastDay = day;
    lastPage = page;
    if (error != null) {
      throw error!;
    }
    final items =
        _events.where((event) => _sameDay(event.occurredAt, day)).toList()
          ..sort(
            (first, second) => second.occurredAt.compareTo(first.occurredAt),
          );
    final size = perPage ?? 20;
    final offset = (page - 1) * size;
    return AuditEventPage(
      items: items.skip(offset).take(size).toList(),
      page: page,
      perPage: size,
      total: items.length,
      totalPages: (items.length / size).ceil(),
    );
  }

  @override
  Future<AuditGraphData> fetchGraph(DateTime day) async {
    graphCalls++;
    if (error != null) {
      throw error!;
    }
    final events = _events.where((event) => _sameDay(event.occurredAt, day));
    if (events.isEmpty) {
      return const AuditGraphData();
    }
    final dayId = 'day:${_isoDate(day)}';
    return AuditGraphData(
      nodes: [
        AuditGraphNode(
          id: dayId,
          type: 'day',
          label: _isoDate(day),
          degree: events.length,
        ),
        for (final event in events)
          AuditGraphNode(
            id: event.source.id,
            type: event.source.type,
            label: event.source.label,
            degree: 1,
          ),
      ],
      edges: [
        for (final event in events)
          AuditGraphEdge(source: dayId, target: event.source.id),
      ],
      totalEvents: events.length,
    );
  }

  static DateTime _dayOf(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static String _isoDate(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final dayOfMonth = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$dayOfMonth';
  }
}
