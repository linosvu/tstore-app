import 'package:flutter/material.dart';

import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/screens/orders/repair_orders_tab_screen.dart';

/// Full-screen Sửa chữa (mở từ Dashboard, không còn trong tab Đơn hàng).
class RepairOrdersScreen extends StatelessWidget {
  const RepairOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ordersSubTabRepair),
      ),
      body: const RepairOrdersTabScreen(),
    );
  }
}
