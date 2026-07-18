import 'package:flutter/material.dart';

import 'package:tstore/screens/service_request/service_support_hub_screen.dart';

/// Full-screen Hỗ trợ & Sửa chữa (mở từ Dashboard).
class RepairOrdersScreen extends StatelessWidget {
  const RepairOrdersScreen({
    super.key,
    this.initialTab = 1,
    this.repairStatusFilter,
    this.repairOverdue = false,
    this.supportStatusFilter,
    this.supportUnassigned = false,
  });

  final int initialTab;
  final String? repairStatusFilter;
  final bool repairOverdue;
  final String? supportStatusFilter;
  final bool supportUnassigned;

  @override
  Widget build(BuildContext context) {
    final isRepair = initialTab == 1;
    return ServiceSupportHubScreen(
      initialTab: initialTab,
      statusFilter: isRepair ? repairStatusFilter : supportStatusFilter,
      overdueOnly: repairOverdue || supportUnassigned,
    );
  }
}
