import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/services/management_quick_access_store.dart';
import 'package:tstore/models/delivery.dart';
import 'package:tstore/models/management_entity.dart';
import 'package:tstore/models/management_filters.dart';
import 'package:tstore/models/preparation_order.dart';
import 'package:tstore/models/sale_order.dart';
import 'package:tstore/models/task.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/management_provider.dart';
import 'package:tstore/screens/delivery/delivery_compact_card.dart';
import 'package:tstore/screens/delivery/delivery_detail_screen.dart';
import 'package:tstore/screens/orders/sale_order_detail_screen.dart';
import 'package:tstore/screens/preparation/preparation_detail_screen.dart';
import 'package:tstore/screens/preparation/preparation_ui.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/list_skeleton.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

import 'package:tstore/screens/tasks/task_detail_screen.dart';
import 'package:tstore/screens/tasks/task_ui.dart';

import 'management_save_quick_access_dialog.dart';
import 'management_status_labels.dart';

class ManagementResultsScreen extends StatefulWidget {
  const ManagementResultsScreen({
    super.key,
    required this.entity,
    required this.filters,
    this.listScope = 'all',
    this.titleOverride,
    this.showQuickAccess = true,
  });

  final ManagementEntity entity;
  final ManagementFilters filters;
  final String listScope;
  final String? titleOverride;
  final bool showQuickAccess;

  @override
  State<ManagementResultsScreen> createState() => _ManagementResultsScreenState();
}

class _ManagementResultsScreenState extends State<ManagementResultsScreen> {
  final _scroll = ScrollController();
  final List<dynamic> _items = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  ManagementProvider get _mgmt =>
      ManagementProvider(api: context.read<AuthProvider>().api);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!_loading && !_loadingMore && _page < _totalPages) {
        _load(reset: false);
      }
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      if (_loading) return;
    } else {
      if (_loadingMore || _loading) return;
    }
    final nextPage = reset ? 1 : _page + 1;
    if (!reset && nextPage > _totalPages) return;

    setState(() {
      _error = null;
      if (reset) {
        _loading = true;
        _loadingMore = false;
      } else {
        _loadingMore = true;
      }
    });

    try {
      switch (widget.entity) {
        case ManagementEntity.saleOrders:
          final r = await _mgmt.fetchSaleOrdersPage(
            filters: widget.filters,
            page: nextPage,
            listScope: widget.listScope,
          );
          if (!mounted) return;
          setState(() {
            if (reset) _items.clear();
            _items.addAll(r.items);
            _page = nextPage;
            _totalPages = r.totalPages;
            _loading = false;
            _loadingMore = false;
          });
        case ManagementEntity.preparations:
          final r = await _mgmt.fetchPreparationsPage(
            filters: widget.filters,
            page: nextPage,
            listScope: widget.listScope,
          );
          if (!mounted) return;
          setState(() {
            if (reset) _items.clear();
            _items.addAll(r.items);
            _page = nextPage;
            _totalPages = r.totalPages;
            _loading = false;
            _loadingMore = false;
          });
        case ManagementEntity.deliveries:
          final r = await _mgmt.fetchDeliveriesPage(
            filters: widget.filters,
            page: nextPage,
            listScope: widget.listScope,
          );
          if (!mounted) return;
          setState(() {
            if (reset) _items.clear();
            _items.addAll(r.items);
            _page = nextPage;
            _totalPages = r.totalPages;
            _loading = false;
            _loadingMore = false;
          });
        case ManagementEntity.tasks:
          final r = await _mgmt.fetchTasksPage(
            filters: widget.filters,
            page: nextPage,
          );
          if (!mounted) return;
          setState(() {
            if (reset) _items.clear();
            _items.addAll(r.items);
            _page = nextPage;
            _totalPages = r.totalPages;
            _loading = false;
            _loadingMore = false;
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ManagementProvider.dioMessage(e);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  String _title(AppLocalizations l10n) {
    if (widget.titleOverride != null && widget.titleOverride!.isNotEmpty) {
      return widget.titleOverride!;
    }
    switch (widget.entity) {
      case ManagementEntity.saleOrders:
        return '${l10n.managementResultsTitle} — ${l10n.managementCardOrders}';
      case ManagementEntity.deliveries:
        return '${l10n.managementResultsTitle} — ${l10n.managementCardDeliveries}';
      case ManagementEntity.preparations:
        return '${l10n.managementResultsTitle} — ${l10n.managementCardPreparations}';
      case ManagementEntity.tasks:
        return '${l10n.managementResultsTitle} — ${l10n.managementCardTasks}';
    }
  }

  String _formatMoney(int v) {
    final f = NumberFormat('#,###', 'vi_VN');
    return '${f.format(v)} đ';
  }

  Future<void> _saveQuickAccess() async {
    final name = await showManagementSaveQuickAccessDialog(context);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await ManagementQuickAccessStore.instance.save(
        name: name,
        entity: widget.entity,
        filters: widget.filters,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).managementSaveQuickAccessSuccess),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title(l10n)),
        actions: [
          if (widget.showQuickAccess)
            TextButton.icon(
              onPressed: _saveQuickAccess,
              icon: const Icon(Icons.bookmark_add_outlined, size: 20),
              label: Text(l10n.managementSaveQuickAccessButton),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: _error != null
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ErrorBanner(
                    message: _error!,
                    retryLabel: l10n.productsRetry,
                    onRetry: () => _load(reset: true),
                  ),
                ],
              )
            : _loading && _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      ListSkeleton(
                        rows: 8,
                        variant: ListSkeletonVariant.orderRow,
                      ),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          EmptyState(message: l10n.ordersListEmpty),
                        ],
                      )
                    : ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenHorizontal,
                          vertical: AppSpacing.space3,
                        ),
                        itemCount: _items.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i >= _items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child:
                                  Center(child: CircularProgressIndicator()),
                            );
                          }
                          final item = _items[i];
                          return _buildRow(context, item, l10n, scheme);
                        },
                      ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    dynamic item,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    switch (widget.entity) {
      case ManagementEntity.saleOrders:
        final o = item as SaleOrderPublic;
        return _SaleOrderResultTile(
          order: o,
          amountText: _formatMoney(o.subtotal),
          statusLabel: managementStatusLabel(
            ManagementEntity.saleOrders,
            o.status,
            l10n,
          ),
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SaleOrderDetailScreen(orderId: o.id),
              ),
            );
          },
        );
      case ManagementEntity.deliveries:
        final d = item as DeliveryPublic;
        return DeliveryCompactCard(
          d: d,
          l10n: l10n,
          scheme: scheme,
          onOpenDetail: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => DeliveryDetailScreen(deliveryId: d.id),
              ),
            );
          },
        );
      case ManagementEntity.preparations:
        final p = item as PreparationOrderPublic;
        return _PrepResultTile(
          item: p,
          l10n: l10n,
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => PreparationDetailScreen(preparationId: p.id),
              ),
            );
          },
        );
      case ManagementEntity.tasks:
        final t = item as TaskPublic;
        return _TaskResultTile(
          task: t,
          l10n: l10n,
          onTap: () {
            Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TaskDetailScreen(taskId: t.id),
              ),
            );
          },
        );
    }
  }
}

class _TaskResultTile extends StatelessWidget {
  const _TaskResultTile({
    required this.task,
    required this.l10n,
    required this.onTap,
  });

  final TaskPublic task;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    formatTaskDueAt(task.dueAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            taskStatusBadge(task, l10n),
          ],
        ),
      ),
    );
  }
}

class _SaleOrderResultTile extends StatelessWidget {
  const _SaleOrderResultTile({
    required this.order,
    required this.amountText,
    required this.statusLabel,
    required this.onTap,
  });

  final SaleOrderPublic order;
  final String amountText;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cust = order.customer?.name ?? '—';
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${order.displayCode}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(cust, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(amountText),
                ],
              ),
            ),
            StatusBadge(label: statusLabel, tone: StatusBadgeTone.neutral),
          ],
        ),
      ),
    );
  }
}

class _PrepResultTile extends StatelessWidget {
  const _PrepResultTile({
    required this.item,
    required this.l10n,
    required this.onTap,
  });

  final PreparationOrderPublic item;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final code = item.code.isNotEmpty
        ? item.code
        : '${item.saleOrderId.substring(0, 8)}-CB';
    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    item.saleOrder?.customer?.name ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: preparationStatusLabel(item.status, l10n),
              tone: preparationStatusTone(item.status),
            ),
          ],
        ),
      ),
    );
  }
}
