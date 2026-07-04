import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/widgets/app_messenger.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/navigation/notification_navigation.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';
import '../../screens/main_shell.dart';
import '../../widgets/ui/empty_state.dart';
import '../../widgets/ui/notification_list_tile.dart';
import '../../widgets/ui/screen_gradient_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().syncFromNotificationCenter();
    });
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.notificationsDeleteAll),
        content: Text(l10n.notificationsDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<NotificationProvider>().deleteAll();
    }
  }

  void _openNotification(BuildContext context, AppNotification n) {
    final provider = context.read<NotificationProvider>();
    provider.markRead(n.id);
    NotificationNavigation.openFromNotification(context, n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<NotificationProvider>();
    final items = provider.items;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenGradientHeader(
              title: l10n.notificationsNav,
              leading: IconButton(
              tooltip: l10n.homeNav,
              icon: const Icon(
                Icons.home_rounded,
                color: AppColors.onPrimary,
              ),
              onPressed: () {
                final shell = MainShellController.maybeOf(context);
                if (shell != null) {
                  shell.goHome();
                } else {
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                }
              },
            ),
            actions: [
              if (items.isNotEmpty) ...[
                IconButton(
                  tooltip: l10n.notificationsMarkAllRead,
                  icon: const Icon(
                    Icons.done_all_rounded,
                    color: AppColors.onPrimary,
                  ),
                  onPressed: provider.unreadCount > 0
                      ? () => provider.markAllRead()
                      : null,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.onPrimary,
                  ),
                  onSelected: (value) {
                    if (value == 'delete_all') {
                      _confirmDeleteAll(context);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'delete_all',
                      child: Text(l10n.notificationsDeleteAll),
                    ),
                  ],
                ),
              ],
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: provider.syncFromNotificationCenter,
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.sizeOf(context).height * 0.45,
                          child: EmptyState(
                            icon: Icons.notifications_none_rounded,
                            message: l10n.notificationsEmpty,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        top: AppSpacing.space2,
                        bottom: AppSpacing.space6,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final n = items[index];
                        return Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: AppColors.error.withValues(alpha: 0.85),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(l10n.delete),
                                content: Text(l10n.notificationsDeleteOneConfirm),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              ),
                            );
                            return ok == true;
                          },
                          onDismissed: (_) {
                            provider.delete(n.id);
                            AppMessenger.showSnackBar(
                              context,
                              SnackBar(content: Text(l10n.notificationsDeleted)),
                            );
                          },
                          child: NotificationListTile(
                            notification: n,
                            l10n: l10n,
                            onTap: () => _openNotification(context, n),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
