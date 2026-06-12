import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/routes.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/app_messenger.dart';
import '../../models/auth_user.dart';
import '../../providers/auth_provider.dart';

/// Shared account dialogs for [SettingsScreen] (and optionally elsewhere).
class ProfileAccountDialogs {
  ProfileAccountDialogs._();

  static Future<void> editEmail(
    BuildContext pageContext,
    AppLocalizations l10n,
    AuthUser current,
  ) async {
    final c = TextEditingController(text: current.email);
    try {
      await showDialog<void>(
        context: pageContext,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.profileEmail),
          content: TextField(
            controller: c,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: l10n.profileEmail,
              hintText: 'ten@example.com',
            ),
            maxLength: 254,
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final err = await pageContext.read<AuthProvider>().patchProfile(email: c.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!pageContext.mounted) return;
                if (err != null) {
                  AppMessenger.showSnackBar(pageContext, SnackBar(content: Text(err)));
                } else {
                  AppMessenger.showSnackBar(
                    pageContext,
                    SnackBar(content: Text(l10n.success), backgroundColor: AppColors.success),
                  );
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      );
    } finally {
      c.dispose();
    }
  }

  static Future<void> changePassword(
    BuildContext pageContext,
    AppLocalizations l10n,
  ) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    try {
      await showDialog<void>(
        context: pageContext,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.profileChangePassword),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.profileCurrentPassword,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.profileNewPassword,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.profileConfirmNewPassword,
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final cur = currentCtrl.text;
                final nw = newCtrl.text;
                final cf = confirmCtrl.text;
                if (nw.length < 6) {
                  AppMessenger.showSnackBar(
                    ctx,
                    SnackBar(content: Text(l10n.profilePasswordMinLength)),
                  );
                  return;
                }
                if (nw != cf) {
                  AppMessenger.showSnackBar(
                    ctx,
                    SnackBar(content: Text(l10n.profilePasswordsDoNotMatch)),
                  );
                  return;
                }
                final err = await pageContext.read<AuthProvider>().changePassword(
                      currentPassword: cur,
                      newPassword: nw,
                    );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (!pageContext.mounted) return;
                if (err != null) {
                  AppMessenger.showSnackBar(pageContext, SnackBar(content: Text(err)));
                } else {
                  AppMessenger.showSnackBar(
                    pageContext,
                    SnackBar(
                      content: Text(l10n.success),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      );
    } finally {
      currentCtrl.dispose();
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
  }

  static Future<void> confirmLogout(
    BuildContext pageContext,
    AppLocalizations l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: pageContext,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileLogoutTitle),
        content: Text(l10n.profileLogoutMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.profileLogoutTitle),
          ),
        ],
      ),
    );
    if (ok != true || !pageContext.mounted) return;
    await pageContext.read<AuthProvider>().logout();
    if (!pageContext.mounted) return;
    Navigator.of(pageContext).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}
