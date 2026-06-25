import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/localization/app_localizations.dart';
import '../../design_system/ts_bottom_nav.dart';
import '../../providers/notification_provider.dart';
import '../../screens/main_shell.dart';

/// Bottom navigation: Home, Orders, Giao Hàng (hub), Thông báo.
class PrimaryBottomNav extends StatelessWidget {
  const PrimaryBottomNav({
    super.key,
    required this.currentIndex,
  });

  /// `0` = Home, `1` = Orders, `2` = Giao Hàng hub, `3` = Thông báo.
  final int currentIndex;

  static const List<String> _routes = [
    AppRoutes.home,
    AppRoutes.orders,
    AppRoutes.delivery,
    AppRoutes.notifications,
  ];

  void _onTap(BuildContext context, int index) {
    if (currentIndex == index) return;
    final shell = MainShellController.maybeOf(context);
    if (shell != null) {
      shell.setIndex(index);
    } else {
      Navigator.pushReplacementNamed(context, _routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unread = context.watch<NotificationProvider>().unreadCount;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Thanh điều hướng chính',
      child: TsBottomNav(
        currentIndex: currentIndex,
        onTap: (i) => _onTap(context, i),
        items: [
          TsBottomNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: l10n.homeNav,
          ),
          TsBottomNavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: l10n.ordersNav,
          ),
          TsBottomNavItem(
            icon: Icons.local_shipping_outlined,
            selectedIcon: Icons.local_shipping_rounded,
            label: l10n.deliveryNav,
          ),
          TsBottomNavItem(
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications_rounded,
            label: l10n.notificationsNav,
            badgeCount: unread,
          ),
        ],
      ),
    );
  }
}
