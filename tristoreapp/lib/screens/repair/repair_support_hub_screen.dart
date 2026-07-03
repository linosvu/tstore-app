import 'package:flutter/material.dart';
import 'package:tstore/core/localization/app_localizations.dart';

import 'repair_orders_list_screen.dart';
import '../support/support_tickets_list_screen.dart';

/// Hub Sửa chữa & Ticket hỗ trợ.
class RepairSupportHubScreen extends StatefulWidget {
  const RepairSupportHubScreen({
    super.key,
    this.initialTab = 0,
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
  State<RepairSupportHubScreen> createState() => _RepairSupportHubScreenState();
}

class _RepairSupportHubScreenState extends State<RepairSupportHubScreen> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.repairSupportHubTitle)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.supportTicketsNav)),
                ButtonSegment(value: 1, label: Text(l10n.ordersSubTabRepair)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                SupportTicketsListScreen(
                  initialStatusFilter: widget.supportStatusFilter,
                  initialUnassigned: widget.supportUnassigned,
                  embedded: true,
                ),
                RepairOrdersListScreen(
                  initialStatusFilter: widget.repairStatusFilter,
                  initialOverdue: widget.repairOverdue,
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
