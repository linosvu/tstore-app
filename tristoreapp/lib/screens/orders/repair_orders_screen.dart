import 'package:flutter/material.dart';

import 'package:tstore/screens/repair/repair_support_hub_screen.dart';

/// Full-screen Sửa chữa & Hỗ trợ (mở từ Dashboard).
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
    return RepairSupportHubScreen(
      initialTab: initialTab,
      repairStatusFilter: repairStatusFilter,
      repairOverdue: repairOverdue,
      supportStatusFilter: supportStatusFilter,
      supportUnassigned: supportUnassigned,
    );
  }
}
