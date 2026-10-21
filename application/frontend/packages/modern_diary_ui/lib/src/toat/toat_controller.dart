import 'dart:async';

import 'package:flutter/foundation.dart';

import 'toat_message.dart';

/// Controla o TOAT: no máximo 3 mensagens, sem duplicar a mesma em sequência,
/// com fechamento automático apenas para sucesso e informação.
class ToatController extends ChangeNotifier {
  static const Duration autoDismissDuration = Duration(seconds: 5);
  static const int maxMessages = 3;

  final List<ToatMessage> _messages = [];
  final Map<String, Timer> _timers = {};
  int _sequence = 0;

  List<ToatMessage> get messages => List.unmodifiable(_messages);

  void show(
    String message, {
    ToatVariant variant = ToatVariant.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (_messages.isNotEmpty) {
      final latest = _messages.first;
      if (latest.message == message && latest.variant == variant) {
        return;
      }
    }

    final toatMessage = ToatMessage(
      id: 'toat_${_sequence++}',
      message: message,
      variant: variant,
      actionLabel: actionLabel,
      onAction: onAction,
    );

    while (_messages.length >= maxMessages) {
      _remove(_messages.last.id);
    }
    _messages.insert(0, toatMessage);

    if (variant == ToatVariant.success || variant == ToatVariant.info) {
      _timers[toatMessage.id] = Timer(
        autoDismissDuration,
        () => dismiss(toatMessage.id),
      );
    }

    notifyListeners();
  }

  void dismiss(String id) {
    final existed = _messages.any((message) => message.id == id);
    if (!existed) {
      return;
    }
    _remove(id);
    notifyListeners();
  }

  void _remove(String id) {
    _timers.remove(id)?.cancel();
    _messages.removeWhere((message) => message.id == id);
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
