import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// Campo de texto multilinha, preenchido e sem borda visível.
class AppTextArea extends StatelessWidget {
  const AppTextArea({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.minLines = 5,
    this.maxLines = 10,
    this.enabled = true,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        alignLabelWithHint: true,
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
    );
  }
}
