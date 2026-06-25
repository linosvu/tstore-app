import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/app_notification.dart';

String formatNotificationRelativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inDays < 1) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return DateFormat('dd/MM/yyyy HH:mm').format(dt.toLocal());
}

IconData notificationCategoryIcon(AppNotificationCategory category) {
  switch (category) {
    case AppNotificationCategory.order:
      return Icons.receipt_long_outlined;
    case AppNotificationCategory.preparation:
      return Icons.inventory_2_outlined;
    case AppNotificationCategory.delivery:
      return Icons.local_shipping_outlined;
    case AppNotificationCategory.system:
      return Icons.notifications_outlined;
  }
}

Color notificationCategoryColor(AppNotificationCategory category) {
  switch (category) {
    case AppNotificationCategory.order:
      return AppColors.primary;
    case AppNotificationCategory.preparation:
      return AppColors.secondary;
    case AppNotificationCategory.delivery:
      return const Color(0xFF2E7D32);
    case AppNotificationCategory.system:
      return AppColors.onSurfaceVariant;
  }
}

String notificationCategoryLabel(
  AppLocalizations l10n,
  AppNotificationCategory category,
) {
  switch (category) {
    case AppNotificationCategory.order:
      return l10n.notificationsCategoryOrder;
    case AppNotificationCategory.preparation:
      return l10n.notificationsCategoryPreparation;
    case AppNotificationCategory.delivery:
      return l10n.notificationsCategoryDelivery;
    case AppNotificationCategory.system:
      return l10n.notificationsCategorySystem;
  }
}

class NotificationListTile extends StatelessWidget {
  const NotificationListTile({
    super.key,
    required this.notification,
    required this.l10n,
    required this.onTap,
  });

  final AppNotification notification;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categoryColor = notificationCategoryColor(notification.category);
    final timeLabel = formatNotificationRelativeTime(notification.createdAt);

    return Material(
      color: notification.isUnread
          ? AppColors.primary.withValues(alpha: 0.04)
          : scheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  notificationCategoryIcon(notification.category),
                  color: categoryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: notification.isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                          ),
                        ),
                        if (notification.isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          notificationCategoryLabel(
                            l10n,
                            notification.category,
                          ),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (notification.orderCode != null &&
                            notification.orderCode!.isNotEmpty) ...[
                          Text(
                            ' · #${notification.orderCode}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          timeLabel,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
