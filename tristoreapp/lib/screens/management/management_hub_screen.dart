import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/services/management_quick_access_store.dart';
import 'package:tstore/models/management_entity.dart';
import 'package:tstore/models/management_filters.dart';
import 'package:tstore/models/management_quick_access.dart';
import 'package:tstore/models/management_stats.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/management_provider.dart';
import 'package:tstore/screens/main_shell.dart';
import 'package:tstore/screens/main_shell_tabs.dart';
import 'package:tstore/screens/orders/orders_tab_launch_args.dart';
import 'package:tstore/widgets/ui/screen_gradient_header.dart';

import 'management_filter_screen.dart';
import 'management_quick_access_section.dart';
import 'management_results_screen.dart';
import 'management_stats_card.dart';

class ManagementHubScreen extends StatefulWidget {
  const ManagementHubScreen({super.key});

  @override
  State<ManagementHubScreen> createState() => _ManagementHubScreenState();
}

class _ManagementHubScreenState extends State<ManagementHubScreen> {
  ManagementFilters _orderFilters = ManagementFilters.empty;
  ManagementFilters _deliveryFilters = ManagementFilters.empty;
  ManagementFilters _prepFilters = ManagementFilters.empty;
  ManagementFilters _taskFilters = ManagementFilters.empty;

  ManagementStatsResponse? _orderStats;
  ManagementStatsResponse? _deliveryStats;
  ManagementStatsResponse? _prepStats;
  ManagementStatsResponse? _taskStats;

  String? _orderErr;
  String? _deliveryErr;
  String? _prepErr;
  String? _taskErr;

  bool _loadingOrders = true;
  bool _loadingDeliveries = true;
  bool _loadingPrep = true;
  bool _loadingTasks = true;

  List<ManagementQuickAccess> _quickAccess = [];

  ManagementProvider get _mgmt =>
      ManagementProvider(api: context.read<AuthProvider>().api);

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadQuickAccess();
  }

  Future<void> _loadQuickAccess() async {
    final items = await ManagementQuickAccessStore.instance.loadAll();
    if (!mounted) return;
    setState(() => _quickAccess = items);
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadEntity(ManagementEntity.saleOrders),
      _loadEntity(ManagementEntity.deliveries),
      _loadEntity(ManagementEntity.preparations),
      _loadEntity(ManagementEntity.tasks),
    ]);
  }

  Future<void> _loadEntity(ManagementEntity entity) async {
    final filters = _filtersFor(entity);
    setState(() {
      switch (entity) {
        case ManagementEntity.saleOrders:
          _loadingOrders = true;
          _orderErr = null;
        case ManagementEntity.deliveries:
          _loadingDeliveries = true;
          _deliveryErr = null;
        case ManagementEntity.preparations:
          _loadingPrep = true;
          _prepErr = null;
        case ManagementEntity.tasks:
          _loadingTasks = true;
          _taskErr = null;
      }
    });
    try {
      final stats = await _mgmt.fetchStats(entity: entity, filters: filters);
      if (!mounted) return;
      setState(() {
        switch (entity) {
          case ManagementEntity.saleOrders:
            _orderStats = stats;
            _loadingOrders = false;
          case ManagementEntity.deliveries:
            _deliveryStats = stats;
            _loadingDeliveries = false;
          case ManagementEntity.preparations:
            _prepStats = stats;
            _loadingPrep = false;
          case ManagementEntity.tasks:
            _taskStats = stats;
            _loadingTasks = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      final msg = ManagementProvider.dioMessage(e) ?? 'Lỗi';
      setState(() {
        switch (entity) {
          case ManagementEntity.saleOrders:
            _orderErr = msg;
            _loadingOrders = false;
          case ManagementEntity.deliveries:
            _deliveryErr = msg;
            _loadingDeliveries = false;
          case ManagementEntity.preparations:
            _prepErr = msg;
            _loadingPrep = false;
          case ManagementEntity.tasks:
            _taskErr = msg;
            _loadingTasks = false;
        }
      });
    }
  }

  ManagementFilters _filtersFor(ManagementEntity entity) {
    switch (entity) {
      case ManagementEntity.saleOrders:
        return _orderFilters;
      case ManagementEntity.deliveries:
        return _deliveryFilters;
      case ManagementEntity.preparations:
        return _prepFilters;
      case ManagementEntity.tasks:
        return _taskFilters;
    }
  }

  Future<void> _openFilter(ManagementEntity entity) async {
    final initial = _filtersFor(entity);
    final result = await Navigator.push<ManagementFilters>(
      context,
      MaterialPageRoute<ManagementFilters>(
        builder: (_) => ManagementFilterScreen(
          entity: entity,
          initialFilters: initial,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      switch (entity) {
        case ManagementEntity.saleOrders:
          _orderFilters = result;
        case ManagementEntity.deliveries:
          _deliveryFilters = result;
        case ManagementEntity.preparations:
          _prepFilters = result;
        case ManagementEntity.tasks:
          _taskFilters = result;
      }
    });
    await _loadEntity(entity);
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ManagementResultsScreen(
          entity: entity,
          filters: result,
        ),
      ),
    );
    if (!mounted) return;
    await _loadQuickAccess();
  }

  Future<void> _openQuickAccess(ManagementQuickAccess item) async {
    await ManagementQuickAccessStore.instance.recordUse(item.id);
    await _loadQuickAccess();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ManagementResultsScreen(
          entity: item.entity,
          filters: item.filters,
        ),
      ),
    );
    if (!mounted) return;
    await _loadQuickAccess();
  }

  Future<void> _confirmDeleteQuickAccess(ManagementQuickAccess item) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.managementQuickAccessDeleteTitle),
        content: Text(l10n.managementQuickAccessDeleteBody(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ManagementQuickAccessStore.instance.remove(item.id);
    await _loadQuickAccess();
  }

  void _onOrderStatusTap(String status) {
    final shell = MainShellController.maybeOf(context);
    if (shell != null) {
      shell.pendingOrdersLaunch = OrdersTabLaunchArgs(status: status);
      shell.setIndex(MainShellTab.orders);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _onStatusResults(ManagementEntity entity, String status) {
    final base = _filtersFor(entity);
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ManagementResultsScreen(
          entity: entity,
          filters: base.copyWith(status: status),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAll();
          await _loadQuickAccess();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ScreenGradientHeader(
                title: l10n.managementHubTitle,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space3,
                AppSpacing.screenHorizontal,
                AppSpacing.space6,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  ManagementQuickAccessSection(
                    items: _quickAccess,
                    onOpen: _openQuickAccess,
                    onDelete: _confirmDeleteQuickAccess,
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  ManagementStatsCard(
                    title: l10n.managementCardOrders,
                    entity: ManagementEntity.saleOrders,
                    stats: _orderStats,
                    filters: _orderFilters,
                    loading: _loadingOrders,
                    error: _orderErr,
                    onFilterTap: () => _openFilter(ManagementEntity.saleOrders),
                    onStatusTap: _onOrderStatusTap,
                    onRetry: () => _loadEntity(ManagementEntity.saleOrders),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  ManagementStatsCard(
                    title: l10n.managementCardDeliveries,
                    entity: ManagementEntity.deliveries,
                    stats: _deliveryStats,
                    filters: _deliveryFilters,
                    loading: _loadingDeliveries,
                    error: _deliveryErr,
                    onFilterTap: () => _openFilter(ManagementEntity.deliveries),
                    onStatusTap: (s) =>
                        _onStatusResults(ManagementEntity.deliveries, s),
                    onRetry: () => _loadEntity(ManagementEntity.deliveries),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  ManagementStatsCard(
                    title: l10n.managementCardPreparations,
                    entity: ManagementEntity.preparations,
                    stats: _prepStats,
                    filters: _prepFilters,
                    loading: _loadingPrep,
                    error: _prepErr,
                    onFilterTap: () => _openFilter(ManagementEntity.preparations),
                    onStatusTap: (s) =>
                        _onStatusResults(ManagementEntity.preparations, s),
                    onRetry: () => _loadEntity(ManagementEntity.preparations),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  ManagementStatsCard(
                    title: l10n.managementCardTasks,
                    entity: ManagementEntity.tasks,
                    stats: _taskStats,
                    filters: _taskFilters,
                    loading: _loadingTasks,
                    error: _taskErr,
                    onFilterTap: () => _openFilter(ManagementEntity.tasks),
                    onStatusTap: (s) =>
                        _onStatusResults(ManagementEntity.tasks, s),
                    onRetry: () => _loadEntity(ManagementEntity.tasks),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
