import 'package:flutter/material.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/design_system/design_system.dart';
import 'package:tstore/screens/orders/repair_orders_screen.dart';
import 'package:tstore/screens/orders/sale_order_flow_screen.dart';
import 'package:tstore/screens/products/products_screen.dart';
import 'package:tstore/screens/main_shell.dart';
import 'package:tstore/screens/tristore/dashboard_drill_down_config.dart';
import 'package:tstore/screens/tristore/dashboard_drill_down_screen.dart';

/// 6 phím tắt dùng chung (trước đây ở trang chủ — chuyển sang Cài đặt).
List<TsCompactServiceItem> buildDashboardShortcutItems(
  BuildContext context,
  AppLocalizations l10n,
) {
  void launchOrders({bool useListAll = true}) {
    MainShellController.maybeOf(context)
        ?.launchOrdersTab(useListAll: useListAll);
  }

  void openDrillDown(DashboardDrillDownKind kind) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DashboardDrillDownScreen(kind: kind),
      ),
    );
  }

  return [
    TsCompactServiceItem(
      label: l10n.ordersDashboardCreate,
      icon: Icons.add_shopping_cart_outlined,
      iconColor: AppColors.primary,
      onTap: () async {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(
            builder: (_) => const SaleOrderFlowScreen(),
          ),
        );
      },
    ),
    TsCompactServiceItem(
      label: l10n.ordersDashboardList,
      icon: Icons.receipt_long_outlined,
      iconColor: AppColors.secondary,
      onTap: () => launchOrders(useListAll: true),
    ),
    TsCompactServiceItem(
      label: l10n.dashboardStatPrepToday,
      icon: Icons.checklist_rounded,
      iconColor: AppColors.success,
      onTap: () => openDrillDown(DashboardDrillDownKind.prepToday),
    ),
    TsCompactServiceItem(
      label: l10n.dashboardStatDeliveryToday,
      icon: Icons.local_shipping_outlined,
      iconColor: AppColors.primary,
      onTap: () => openDrillDown(DashboardDrillDownKind.deliveryToday),
    ),
    TsCompactServiceItem(
      label: l10n.ordersSubTabRepair,
      icon: Icons.build_outlined,
      iconColor: AppColors.warning,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const RepairOrdersScreen(),
          ),
        );
      },
    ),
    TsCompactServiceItem(
      label: l10n.productsNav,
      icon: Icons.inventory_2_outlined,
      iconColor: AppColors.secondary,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ProductsScreen(),
          ),
        );
      },
    ),
  ];
}
