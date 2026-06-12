import 'package:flutter/material.dart';

import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/management_quick_access.dart';

Future<String?> showManagementSaveQuickAccessDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final controller = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(l10n.managementSaveQuickAccessTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: ManagementQuickAccess.maxNameLength,
          decoration: InputDecoration(
            hintText: l10n.managementSaveQuickAccessHint,
            counterText: '',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, name);
            },
            child: Text(l10n.managementSaveQuickAccessButton),
          ),
        ],
      );
    },
  );
}
