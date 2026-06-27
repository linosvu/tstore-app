import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/screens/management/management_results_screen.dart';
import 'package:tstore/screens/tristore/dashboard_drill_down_config.dart';

/// Màn danh sách mở từ tile Dashboard (đơn / phiếu CB / giao hàng).
class DashboardDrillDownScreen extends StatelessWidget {
  const DashboardDrillDownScreen({
    super.key,
    required this.kind,
  });

  final DashboardDrillDownKind kind;

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user;
    final canListAll = user != null &&
        (user.role == 'staff' ||
            user.role == 'admin' ||
            user.role == 'manager');
    final config = DashboardDrillDownConfig.fromKind(
      kind,
      l10n: AppLocalizations.of(context),
      isElevated: canListAll,
    );
    return ManagementResultsScreen(
      entity: config.entity,
      filters: config.filters,
      listScope: config.listScope,
      titleOverride: config.title,
      showQuickAccess: false,
    );
  }
}
