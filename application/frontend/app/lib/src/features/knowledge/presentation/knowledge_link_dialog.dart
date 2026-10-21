import 'package:flutter/material.dart';
import 'package:modern_diary_ui/modern_diary_ui.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/knowledge_models.dart';

/// Pede um link externo: endereço obrigatório e nome opcional.
Future<KnowledgeExternalLink?> showKnowledgeLinkDialog(BuildContext context) {
  return showAppDialog<KnowledgeExternalLink>(
    context,
    title: AppStrings.knowledgeNewLinkTitle,
    closeLabel: AppStrings.close,
    maxWidth: 440,
    child: const _LinkFormBody(),
  );
}

class _LinkFormBody extends StatefulWidget {
  const _LinkFormBody();

  @override
  State<_LinkFormBody> createState() => _LinkFormBodyState();
}

class _LinkFormBodyState extends State<_LinkFormBody> {
  final _urlController = TextEditingController();
  final _labelController = TextEditingController();
  String? _urlError;

  @override
  void dispose() {
    _urlController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _urlController.text.trim();
    final isInvalid = !url.startsWith('http://') && !url.startsWith('https://');

    setState(() {
      _urlError = isInvalid ? AppStrings.knowledgeInvalidLink : null;
    });
    if (isInvalid) {
      return;
    }

    final label = _labelController.text.trim();
    Navigator.of(
      context,
    ).pop(KnowledgeExternalLink(url: url, label: label.isEmpty ? null : label));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _urlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: AppStrings.knowledgeLinkUrlLabel,
            hintText: AppStrings.knowledgeLinkUrlHint,
            errorText: _urlError,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _labelController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: AppStrings.knowledgeLinkLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(AppStrings.cancel),
            ),
            AppButton(
              label: AppStrings.knowledgeAddLink,
              icon: Icons.add_link_rounded,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
