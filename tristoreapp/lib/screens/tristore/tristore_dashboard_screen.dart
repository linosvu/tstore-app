import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/constants/routes.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/user_role_labels.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/models/dashboard_today.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/screens/main_shell.dart';
import 'package:tstore/models/task.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/providers/tasks_provider.dart';
import 'package:tstore/screens/orders/repair_orders_screen.dart';
import 'package:tstore/screens/tasks/task_create_screen.dart';
import 'package:tstore/screens/tasks/task_detail_screen.dart';
import 'package:tstore/screens/tasks/task_ui.dart';
import 'package:tstore/screens/tasks/tasks_list_screen.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/screens/orders/sale_order_flow_screen.dart';
import 'package:tstore/screens/products/products_screen.dart';
import 'package:tstore/screens/management/management_hub_screen.dart';
import 'package:tstore/screens/tristore/dashboard_drill_down_config.dart';
import 'package:tstore/screens/tristore/dashboard_drill_down_screen.dart';
import 'package:tstore/design_system/design_system.dart';
import 'package:tstore/widgets/ui/menu_group_card.dart';

/// Trang chủ — tổng quan trong ngày + nhắc nhở (API `/admin/dashboard/today`).
class TristoreDashboardScreen extends StatefulWidget {
  const TristoreDashboardScreen({super.key});

  @override
  State<TristoreDashboardScreen> createState() => _TristoreDashboardScreenState();
}

class _TristoreDashboardScreenState extends State<TristoreDashboardScreen> {
  DashboardTodayResponse? _summary;
  RepairSupportStats? _repairSupport;
  String? _err;
  bool _loading = true;
  String? _taskFilter;
  bool _taskOverdueFilter = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetch();
      context.read<TasksProvider>().loadRecent();
    });
  }

  List<TaskPublic> _filteredRecent(TasksProvider p) {
    var items = p.recent;
    if (_taskOverdueFilter) {
      return items.where((t) => t.isOverdue).toList();
    }
    if (_taskFilter != null) {
      return items.where((t) => t.status == _taskFilter).toList();
    }
    return items;
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final res = await context.read<AuthProvider>().api.get<Map<String, dynamic>>(
            '/admin/dashboard/today',
          );
      final data = res.data;
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _summary = null;
          _err = 'Dữ liệu rỗng';
          _loading = false;
        });
        return;
      }
      setState(() {
        _summary = DashboardTodayResponse.fromJson(data);
        _loading = false;
      });
      final stats = await context.read<ServiceRequestsProvider>().fetchStats();
      if (mounted && stats != null) {
        setState(() => _repairSupport = stats);
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.response?.data?.toString() ?? e.message ?? 'Lỗi mạng';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
        _loading = false;
      });
    }
  }

  String _num(int? v) {
    if (_loading) return '—';
    return '${v ?? 0}';
  }

  String _money(int? v) {
    if (_loading || v == null) return '—';
    return '${formatIntegerWithSeparator(v, ThousandsGroupSeparatorKey.dot)} đ';
  }

  void _launchOrders({String? status, bool useListAll = true}) {
    MainShellController.maybeOf(context)
        ?.launchOrdersTab(status: status, useListAll: useListAll);
  }

  void _openDrillDown(DashboardDrillDownKind kind) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DashboardDrillDownScreen(kind: kind),
      ),
    );
  }

  void _openRepairHub({
    int tab = 1,
    String? repairStatus,
    bool repairOverdue = false,
    String? supportStatus,
    bool supportUnassigned = false,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RepairOrdersScreen(
          initialTab: tab,
          repairStatusFilter: repairStatus,
          repairOverdue: repairOverdue,
          supportStatusFilter: supportStatus,
          supportUnassigned: supportUnassigned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = _summary;
    final rs = _repairSupport;
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.role == 'admin';
    final todayOverviewItems = <TsTodayOverviewItem>[
      TsTodayOverviewItem(
        label: l10n.dashboardStatOrdersToday,
        value: _num(s?.todayOrders),
        hint: l10n.dashboardStatOrdersTodayHint,
        icon: Icons.receipt_long_rounded,
        color: AppColors.primary,
        onTap: () => _openDrillDown(DashboardDrillDownKind.ordersToday),
      ),
      if (isAdmin)
        TsTodayOverviewItem(
          label: l10n.dashboardStatOrdersTodayTotal,
          value: _money(s?.todayOrdersTotalAmount),
          hint: l10n.dashboardStatOrdersTodayTotalHint,
          icon: Icons.payments_rounded,
          color: AppColors.secondary,
          onTap: () => _openDrillDown(DashboardDrillDownKind.ordersToday),
        ),
      TsTodayOverviewItem(
        label: l10n.dashboardStatPrepToday,
        value: _num(s?.todayPreparations),
        hint: l10n.dashboardStatPrepTodayHint,
        icon: Icons.checklist_rounded,
        color: AppColors.success,
        onTap: () => _openDrillDown(DashboardDrillDownKind.prepToday),
      ),
      TsTodayOverviewItem(
        label: l10n.dashboardStatDeliveryToday,
        value: _num(s?.todayDeliveries),
        hint: l10n.dashboardStatDeliveryTodayHint,
        icon: Icons.local_shipping_rounded,
        color: AppColors.primary,
        onTap: () => _openDrillDown(DashboardDrillDownKind.deliveryToday),
      ),
      TsTodayOverviewItem(
        label: l10n.dashboardStatRepairsOpen,
        value: _num(rs?.repairs.openCount),
        hint: l10n.ordersSubTabRepair,
        icon: Icons.build_outlined,
        color: AppColors.warning,
        onTap: () => _openRepairHub(tab: 1),
      ),
      TsTodayOverviewItem(
        label: l10n.dashboardStatSupportOpen,
        value: _num(rs?.support.openCount),
        hint: l10n.supportTicketsNav,
        icon: Icons.support_agent_outlined,
        color: AppColors.secondary,
        onTap: () => _openRepairHub(tab: 0),
      ),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetch();
          await context.read<TasksProvider>().loadRecent();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.space3,
                  AppSpacing.screenHorizontal,
                  AppSpacing.sectionGap,
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Xin chào${user != null ? ', ${user.fullName.split(' ').first}' : ''}',
                                  style: const TextStyle(
                                    color: AppColors.onPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (user != null)
                                  Text(
                                    roleLabelVi(user.role),
                                    style: TextStyle(
                                      color: AppColors.onPrimary
                                          .withValues(alpha: 0.85),
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.settings,
                            icon: const Icon(
                              Icons.settings_rounded,
                              color: AppColors.onPrimary,
                            ),
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRoutes.settings),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                  TsCompactServiceGrid(
                    items: [
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
                        onTap: () => _launchOrders(useListAll: true),
                      ),
                      TsCompactServiceItem(
                        label: l10n.dashboardStatPrepToday,
                        icon: Icons.checklist_rounded,
                        iconColor: AppColors.success,
                        onTap: () =>
                            _openDrillDown(DashboardDrillDownKind.prepToday),
                      ),
                      TsCompactServiceItem(
                        label: l10n.dashboardStatDeliveryToday,
                        icon: Icons.local_shipping_outlined,
                        iconColor: AppColors.primary,
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.deliveryToday,
                        ),
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
                    ],
                  ),
                  if (user != null &&
                      (user.role == 'admin' || user.role == 'manager')) ...[
                    const SizedBox(height: AppSpacing.space3),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const ManagementHubScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.insights_outlined),
                        label: Text(l10n.managementOpen),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sectionGap),
                  Text(
                    l10n.dashboardTodayTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (s != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        s.scope == 'all'
                            ? l10n.dashboardScopeAll
                            : l10n.dashboardScopeMine,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    ),
                  if (_err != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _err!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.space3),
                  TsTodayOverviewList(items: todayOverviewItems),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.tasksDashboardSection,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const TasksListScreen(),
                            ),
                          );
                        },
                        child: Text(l10n.tasksViewAll),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        taskFilterChip(
                          label: l10n.tasksFilterAll,
                          selected: _taskFilter == null && !_taskOverdueFilter,
                          onTap: () => setState(() {
                            _taskFilter = null;
                            _taskOverdueFilter = false;
                          }),
                        ),
                        taskFilterChip(
                          label: l10n.tasksStatusPending,
                          selected: _taskFilter == 'pending',
                          onTap: () => setState(() {
                            _taskFilter = 'pending';
                            _taskOverdueFilter = false;
                          }),
                        ),
                        taskFilterChip(
                          label: l10n.tasksStatusInProgress,
                          selected: _taskFilter == 'in_progress',
                          onTap: () => setState(() {
                            _taskFilter = 'in_progress';
                            _taskOverdueFilter = false;
                          }),
                        ),
                        taskFilterChip(
                          label: l10n.tasksStatusOverdue,
                          selected: _taskOverdueFilter,
                          onTap: () => setState(() {
                            _taskFilter = null;
                            _taskOverdueFilter = true;
                          }),
                        ),
                        taskFilterChip(
                          label: l10n.tasksStatusCompleted,
                          selected: _taskFilter == 'completed',
                          onTap: () => setState(() {
                            _taskFilter = 'completed';
                            _taskOverdueFilter = false;
                          }),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Consumer<TasksProvider>(
                    builder: (context, tp, _) {
                      if (tp.isLoadingRecent) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      if (tp.recentError != null) {
                        return Text(
                          tp.recentError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        );
                      }
                      final shown = _filteredRecent(tp).take(5).toList();
                      if (shown.isEmpty) {
                        return Text(
                          l10n.tasksDashboardEmpty,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                        );
                      }
                      return Column(
                        children: shown
                            .map(
                              (t) => AppSurfaceCard(
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.space2,
                                ),
                                padding: const EdgeInsets.all(AppSpacing.space3),
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push<void>(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => TaskDetailScreen(
                                          taskId: t.id,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    t.title,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                taskPriorityFlag(t),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${l10n.tasksDueLabel}: ${formatTaskDueAt(t.dueAt)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppColors
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      taskStatusBadge(t, l10n),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                        style: BorderStyle.solid,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute<bool>(
                          builder: (_) => const TaskCreateScreen(),
                        ),
                      );
                      if (mounted) {
                        context.read<TasksProvider>().loadRecent();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.tasksCreateNew),
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Text(
                    l10n.dashboardReminderOpsTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  MenuGroupCard(
                    items: [
                      MenuGroupItem(
                        title: l10n.dashboardReminderOverdue,
                        icon: Icons.warning_amber_rounded,
                        iconColor: AppColors.error,
                        trailing: Text(
                          _num(s?.reminderOverdueOrders),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        // Overdue = confirmed/delivery orders past expectedDeliveryAt
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.overdueOrders,
                        ),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderDueWithin24h,
                        icon: Icons.schedule_rounded,
                        iconColor: AppColors.warning,
                        trailing: Text(
                          _num(s?.reminderDueWithin24h),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.dueWithin24h,
                        ),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderScheduledDelivery24h,
                        icon: Icons.event_available_outlined,
                        iconColor: AppColors.primary,
                        trailing: Text(
                          _num(s?.reminderScheduledDeliveryWithin24h),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.scheduledDelivery24h,
                        ),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderNoPrepAssignee,
                        icon: Icons.person_off_outlined,
                        iconColor: Colors.teal,
                        trailing: Text(
                          _num(s?.reminderOrdersWithoutPrepAssignee),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.noPrepAssignee,
                        ),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderNoDeliveryAssignee,
                        icon: Icons.local_shipping_outlined,
                        iconColor: Colors.blue,
                        trailing: Text(
                          _num(s?.reminderDeliveriesWithoutAssignee),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.noDeliveryAssignee,
                        ),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderRepairOverdue,
                        icon: Icons.build_circle_outlined,
                        iconColor: AppColors.error,
                        trailing: Text(
                          _num(rs?.repairs.overdue),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openRepairHub(tab: 1, repairOverdue: true),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderSupportWaiting,
                        icon: Icons.mark_chat_unread_outlined,
                        iconColor: AppColors.warning,
                        trailing: Text(
                          _num(rs?.support.overdue),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () =>
                            _openRepairHub(tab: 0, supportUnassigned: true),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderRepairWaitingParts,
                        icon: Icons.settings_outlined,
                        iconColor: AppColors.secondary,
                        trailing: Text(
                          _num(rs?.repairs.awaitingApproval),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openRepairHub(
                          tab: 1,
                          repairStatus: 'processing',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sectionGap),
                  Text(
                    l10n.dashboardReminders,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  MenuGroupCard(
                    items: [
                      MenuGroupItem(
                        title: l10n.dashboardReminderDraft,
                        icon: Icons.edit_note_outlined,
                        iconColor: AppColors.primary,
                        trailing: Text(
                          _num(s?.reminderDraftOrTemp),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.draftOrTemp,
                        ),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderPrep,
                        icon: Icons.checklist_rounded,
                        iconColor: Colors.teal,
                        trailing: Text(
                          _num(s?.reminderPrepToDo),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () =>
                            _openDrillDown(DashboardDrillDownKind.prepToDo),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderDelivery,
                        icon: Icons.local_shipping_outlined,
                        iconColor: Colors.blue,
                        trailing: Text(
                          _num(s?.reminderDeliveriesToDo),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.deliveryToDo,
                        ),
                      ),
                      MenuGroupItem(
                        title: l10n.dashboardReminderScheduledPayment,
                        icon: Icons.payments_outlined,
                        iconColor: AppColors.warning,
                        trailing: Text(
                          _num(s?.reminderScheduledPayments),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        onTap: () => _openDrillDown(
                          DashboardDrillDownKind.scheduledPayment,
                        ),
                      ),
                    ],
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

