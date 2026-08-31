import 'package:flutter/material.dart';

import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/screens/orders/orders_list_screen.dart';
import 'package:tstore/screens/service_request/service_request_list_screen.dart';

/// Hub «Cần xử lý hôm nay» — 3 tab danh sách thu gọn.
class ActionTodayScreen extends StatefulWidget {
  const ActionTodayScreen({super.key});

  @override
  State<ActionTodayScreen> createState() => _ActionTodayScreenState();
}

class _ActionTodayScreenState extends State<ActionTodayScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _ordersTotal = 0;
  int _supportTotal = 0;
  int _repairTotal = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.actionTodayTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: l10n.actionTodayTabOrders(_ordersTotal)),
            Tab(text: l10n.actionTodayTabSupport(_supportTotal)),
            Tab(text: l10n.actionTodayTabRepair(_repairTotal)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OrdersListScreen(
            listOnly: true,
            expectedDeliveryToday: true,
            onTotalChanged: (n) {
              if (mounted && _ordersTotal != n) {
                setState(() => _ordersTotal = n);
              }
            },
          ),
          ServiceRequestListScreen(
            tab: 'support',
            listOnly: true,
            initialDueTodayOnly: true,
            onTotalChanged: (n) {
              if (mounted && _supportTotal != n) {
                setState(() => _supportTotal = n);
              }
            },
          ),
          ServiceRequestListScreen(
            tab: 'repair',
            listOnly: true,
            initialDueTodayOnly: true,
            onTotalChanged: (n) {
              if (mounted && _repairTotal != n) {
                setState(() => _repairTotal = n);
              }
            },
          ),
        ],
      ),
    );
  }
}
