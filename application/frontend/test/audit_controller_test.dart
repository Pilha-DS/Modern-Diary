import 'package:flutter_test/flutter_test.dart';
import 'package:modern_diary/src/core/network/api_exception.dart';
import 'package:modern_diary/src/features/audit/domain/audit_models.dart';
import 'package:modern_diary/src/features/audit/presentation/audit_controller.dart';

import 'support/fake_audit_data_source.dart';

AuditEvent _event({
  required DateTime at,
  required String label,
  String type = 'knowledge',
  AuditEventKind kind = AuditEventKind.create,
  AuditEntity? target,
}) {
  return AuditEvent(
    id: at.millisecondsSinceEpoch,
    occurredAt: at,
    kind: kind,
    source: AuditEntity(type: type, ref: '1', label: label),
    target: target,
  );
}

void main() {
  test('abre no dia atual com o mês e o histórico carregados', () async {
    final today = DateTime(2026, 10, 21, 14, 30);
    final source = FakeAuditDataSource(
      events: [
        _event(at: today, label: 'SQL'),
        _event(at: DateTime(2026, 10, 20, 9), label: 'Índices'),
      ],
    );
    final controller = AuditController(source, today: today);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.selectedDay, DateTime(2026, 10, 21));
    expect(controller.month, DateTime(2026, 10));
    expect(controller.daysOfMonth.keys, containsAll([20, 21]));
    expect(controller.events.single.source.label, 'SQL');
    expect(controller.graph.nodes, isNotEmpty);
    expect(controller.total, 1);
    expect(controller.isLoading, isFalse);
    expect(controller.error, isNull);
    expect(source.lastFrom, DateTime(2026, 10, 1));
    expect(source.lastTo, DateTime(2026, 10, 31));
  });

  test('escolher outro dia do mesmo mês só recarrega o dia', () async {
    final today = DateTime(2026, 10, 21, 14, 30);
    final source = FakeAuditDataSource(
      events: [_event(at: DateTime(2026, 10, 12, 8), label: 'Banco')],
    );
    final controller = AuditController(source, today: today);
    addTearDown(controller.dispose);
    await controller.initialize();
    final monthCalls = source.monthCalls;

    await controller.selectDay(DateTime(2026, 10, 12));

    expect(controller.selectedDay, DateTime(2026, 10, 12));
    expect(controller.events.single.source.label, 'Banco');
    expect(source.monthCalls, monthCalls);
    expect(source.lastDay, DateTime(2026, 10, 12));
  });

  test('trocar o mês abre o dia 1 e recarrega as marcas', () async {
    final today = DateTime(2026, 10, 21);
    final source = FakeAuditDataSource(
      events: [_event(at: DateTime(2026, 11, 3, 10), label: 'Novembro')],
    );
    final controller = AuditController(source, today: today);
    addTearDown(controller.dispose);
    await controller.initialize();

    await controller.moveMonth(1);

    expect(controller.month, DateTime(2026, 11));
    expect(controller.selectedDay, DateTime(2026, 11, 1));
    expect(controller.daysOfMonth.keys, contains(3));
    expect(source.lastFrom, DateTime(2026, 11, 1));
    expect(source.lastTo, DateTime(2026, 11, 30));

    await controller.moveMonth(-2);

    expect(controller.month, DateTime(2026, 9));
    expect(controller.selectedDay, DateTime(2026, 9, 1));
  });

  test('carrega mais ações sem repetir a página', () async {
    final today = DateTime(2026, 10, 21);
    final source = FakeAuditDataSource(
      events: [
        for (var hour = 0; hour < 25; hour++)
          _event(at: DateTime(2026, 10, 21, hour % 24), label: 'Ação $hour'),
      ],
    );
    final controller = AuditController(source, today: today);
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(controller.events, hasLength(20));
    expect(controller.hasMore, isTrue);

    await controller.loadMore();

    expect(controller.events, hasLength(25));
    expect(controller.hasMore, isFalse);
    expect(source.lastPage, 2);
  });

  test('erro da API vira estado de erro com retry', () async {
    final source = FakeAuditDataSource(
      error: const ApiException(code: 'NETWORK_ERROR', message: 'Sem conexão.'),
    );
    final controller = AuditController(source, today: DateTime(2026, 10, 21));
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.error?.message, 'Sem conexão.');
    expect(controller.events, isEmpty);
    expect(controller.graph.nodes, isEmpty);
    expect(controller.isLoading, isFalse);
  });
}
