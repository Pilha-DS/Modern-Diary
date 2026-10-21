import 'package:flutter/foundation.dart';

enum ToatVariant { success, info, warning, error }

class ToatMessage {
  const ToatMessage({
    required this.id,
    required this.message,
    required this.variant,
    this.actionLabel,
    this.onAction,
  });

  final String id;
  final String message;
  final ToatVariant variant;
  final String? actionLabel;
  final VoidCallback? onAction;
}
