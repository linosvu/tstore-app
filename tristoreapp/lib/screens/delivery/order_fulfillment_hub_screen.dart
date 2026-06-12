import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/delivery.dart';
import 'package:tstore/models/order_fulfillment.dart';
import 'package:tstore/models/preparation_order.dart';
import 'package:tstore/core/constants/routes.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/screens/delivery/delivery_detail_screen.dart';
import 'package:tstore/screens/main_shell.dart';
import 'package:tstore/screens/orders/sale_order_detail_screen.dart';
import 'package:tstore/screens/delivery/delivery_ui.dart';
import 'package:tstore/screens/preparation/preparation_detail_screen.dart';
import 'package:tstore/screens/preparation/preparation_ui.dart';
import 'package:tstore/widgets/ui/app_search_bar.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/list_skeleton.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/widgets/ui/screen_gradient_header.dart';
import 'package:tstore/widgets/sale_order_code_link_row.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

/// Hub Giao hàng: mỗi đơn bán + panel Chuẩn bị / Giao hàng (theo API fulfillment).
class OrderFulfillmentHubScreen extends StatefulWidget {
  const OrderFulfillmentHubScreen({super.key});

  @override
  State<OrderFulfillmentHubScreen> createState() =>
      _OrderFulfillmentHubScreenState();
}

class _OrderFulfillmentHubScreenState extends State<OrderFulfillmentHubScreen> {
  final List<OrderFulfillmentItem> _items = [];
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String _scope = 'mine';
  int _scopeSegment = 1;
  /// `null` | open | completed | cancelled
  String? _outcomeFilter;
  /// `null` | due_soon | overdue
  String? _expectedDeliveryFilter;
  void _consumePendingLaunch() {
    final shell = MainShellController.maybeOf(context);
    final launch = shell?.pendingFulfillmentLaunch;
    if (launch == null) return;
    shell!.pendingFulfillmentLaunch = null;
    if (launch.outcome != null) _outcomeFilter = launch.outcome;
    if (launch.expectedDelivery != null) {
      _expectedDeliveryFilter = launch.expectedDelivery;
    }
    if (launch.scope != null) {
      const scopeValues = ['board', 'mine'];
      final idx = scopeValues.indexOf(launch.scope!);
      if (idx >= 0) {
        _scope = launch.scope!;
        _scopeSegment = idx;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    const allowedScopes = {'mine', 'board'};
    if (!allowedScopes.contains(_scope)) {
      _scope = 'mine';
      _scopeSegment = 1;
    }
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _consumePendingLaunch();
      _load(reset: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
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

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load(reset: true);
    });
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

    final api = context.read<AuthProvider>().api;
    const allowedScopes = {'mine', 'board'};
    final listScope = allowedScopes.contains(_scope) ? _scope : 'mine';
    final q = <String, dynamic>{
      'page': nextPage,
      'limit': 20,
      'list': listScope,
    };
    if (_outcomeFilter != null) q['fulfillmentOutcome'] = _outcomeFilter;
    if (_expectedDeliveryFilter != null) {
      q['expectedDeliveryFilter'] = _expectedDeliveryFilter;
    }
    final s = _searchCtrl.text.trim();
    if (s.isNotEmpty) q['search'] = s;

    try {
      final res = await api.get<Map<String, dynamic>>(
        '/admin/sale-orders/fulfillment',
        queryParameters: q,
      );
      final data = res.data;
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _loading = false;
          _loadingMore = false;
          _error = 'Dữ liệu rỗng';
        });
        return;
      }
      final parsed = OrderFulfillmentListResult.fromJson(data);
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(parsed.items);
        } else {
          _items.addAll(parsed.items);
        }
        _page = nextPage;
        _totalPages = parsed.totalPages;
        _loading = false;
        _loadingMore = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.response?.data?.toString() ?? e.message ?? 'Lỗi mạng';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  String _formatMoney(int v) {
    return '${v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        )} đ';
  }

  static const _scopeValues = ['board', 'mine'];

  static String _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) return m;
      if (m is List && m.isNotEmpty) return m.map((x) => '$x').join(', ');
    }
    return e.message ?? 'Lỗi';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenGradientHeader(
              title: l10n.deliveryNav,
              leading: IconButton(
                tooltip: l10n.homeNav,
                icon: const Icon(
                  Icons.home_rounded,
                  color: AppColors.onPrimary,
                ),
                onPressed: () {
                  final shell = MainShellController.maybeOf(context);
                  if (shell != null) {
                    shell.goHome();
                  } else {
                    Navigator.pushReplacementNamed(context, AppRoutes.home);
                  }
                },
              ),
              actions: [
                IconButton(
                  tooltip: l10n.deliveryRetry,
                  onPressed: () => _load(reset: true),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.onPrimary,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space1,
                AppSpacing.screenHorizontal,
                AppSpacing.space1,
              ),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text(l10n.fulfillmentScopeBoard),
                    icon: const Icon(Icons.dashboard_outlined, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(l10n.fulfillmentScopeMine),
                    icon: const Icon(Icons.person_outline, size: 18),
                  ),
                ],
                selected: {_scopeSegment},
                onSelectionChanged: (Set<int> next) {
                  final idx = next.first;
                  if (idx == _scopeSegment) return;
                  setState(() {
                    _scopeSegment = idx;
                    _scope = _scopeValues[idx];
                  });
                  _load(reset: true);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
                AppSpacing.screenHorizontal,
                AppSpacing.space1,
              ),
              child: AppSearchBar(
                controller: _searchCtrl,
                hintText: l10n.ordersSearchHint,
                onChanged: (_) => _onSearchChanged(),
                onClear: () => _onSearchChanged(),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.space1,
                ),
                children: [
                  _outcomeChip(null, l10n.ordersFilterAll, scheme),
                  const SizedBox(width: AppSpacing.space2),
                  _outcomeChip('open', l10n.fulfillmentFilterOpen, scheme),
                  const SizedBox(width: AppSpacing.space2),
                  _outcomeChip(
                    'completed',
                    l10n.fulfillmentFilterCompleted,
                    scheme,
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  _outcomeChip(
                    'cancelled',
                    l10n.fulfillmentFilterCancelled,
                    scheme,
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: AppSpacing.space1,
                ),
                children: [
                  _expectedChip('due_soon', l10n.managementExpectedDueSoon, scheme),
                  const SizedBox(width: AppSpacing.space2),
                  _expectedChip(
                    'overdue',
                    l10n.managementExpectedOverdue,
                    scheme,
                  ),
                ],
              ),
            ),
            if (_loading && _items.isEmpty)
              const Divider(height: 2)
            else if (_loading || _loadingMore)
              const LinearProgressIndicator(minHeight: 2)
            else
              const Divider(height: 2),
            Expanded(child: _buildBody(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _outcomeChip(String? value, String label, ColorScheme scheme) {
    final selected = _outcomeFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.primary : scheme.onSurface,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onSelected: (sel) {
        setState(() => _outcomeFilter = sel ? value : null);
        _load(reset: true);
      },
    );
  }

  Widget _expectedChip(String value, String label, ColorScheme scheme) {
    final selected = _expectedDeliveryFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.primary : scheme.onSurface,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onSelected: (sel) {
        setState(() {
          _expectedDeliveryFilter = sel ? value : null;
        });
        _load(reset: true);
      },
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          ErrorBanner(
            message: _error!,
            retryLabel: l10n.productsRetry,
            onRetry: () => _load(reset: true),
          ),
        ],
      );
    }
    if (_loading && _items.isEmpty) {
      return const ListSkeleton(
        rows: 6,
        variant: ListSkeletonVariant.fulfillment,
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          EmptyState(
            message: _searchCtrl.text.trim().isNotEmpty
                ? l10n.ordersListSearchEmpty
                : l10n.ordersListEmpty,
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
          AppSpacing.screenHorizontal,
          AppSpacing.space4,
        ),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final userId = context.read<AuthProvider>().user?.id ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: _FulfillmentCard(
              item: _items[i],
              l10n: l10n,
              currentUserId: userId,
              collapseInactiveLegs: _scope == 'mine',
              formatMoney: _formatMoney,
              onOpenOrder: (id) {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SaleOrderDetailScreen(orderId: id),
                  ),
                ).then((_) => _load(reset: true));
              },
              onOpenPrep: (id) {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PreparationDetailScreen(preparationId: id),
                  ),
                ).then((_) => _load(reset: true));
              },
              onOpenDelivery: (id) {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DeliveryDetailScreen(deliveryId: id),
                  ),
                ).then((_) => _load(reset: true));
              },
            ),
          );
        },
      ),
    );
  }
}

bool isFulfillmentLegMine(String? assignedUserId, String currentUserId) {
  if (currentUserId.isEmpty) return false;
  return assignedUserId != null &&
      assignedUserId.isNotEmpty &&
      assignedUserId == currentUserId;
}

String fulfillmentLegSubtitle(
  AppLocalizations l10n, {
  String? assignedUserId,
  String? assigneeName,
}) {
  final name = assigneeName?.trim();
  if (name != null && name.isNotEmpty) return name;
  if (assignedUserId != null && assignedUserId.isNotEmpty) {
    return assignedUserId;
  }
  return l10n.fulfillmentLegUnassigned;
}

class _FulfillmentCard extends StatelessWidget {
  const _FulfillmentCard({
    required this.item,
    required this.l10n,
    required this.currentUserId,
    required this.collapseInactiveLegs,
    required this.formatMoney,
    required this.onOpenOrder,
    required this.onOpenPrep,
    required this.onOpenDelivery,
  });

  final OrderFulfillmentItem item;
  final AppLocalizations l10n;
  final String currentUserId;
  final bool collapseInactiveLegs;
  final String Function(int) formatMoney;
  final void Function(String orderId) onOpenOrder;
  final void Function(String prepId) onOpenPrep;
  final void Function(String deliveryId) onOpenDelivery;

  @override
  Widget build(BuildContext context) {
    final o = item.saleOrder;
    final hasPrep = item.preparation != null;
    final hasDel = item.delivery != null;
    final wide = MediaQuery.sizeOf(context).width >= 560;

    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => onOpenOrder(o.id),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            o.customer?.name ?? l10n.deliveryCustomer,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: _saleStatusVi(o.status, l10n),
                          tone: StatusBadgeTone.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SaleOrderCodeLinkRow(
                      saleOrderId: o.id,
                      displayCode: o.displayCode,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${l10n.ordersSubtotal}: ${formatMoney(o.subtotal)} · ${l10n.ordersAmountDue}: ${formatMoney(o.amountDue)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if ((o.expectedDeliveryAt ?? '').trim().isNotEmpty)
                      Text(
                        '${l10n.saleOrderExpectedDeliveryTitle}: ${deliveryScheduledFormatted(o.expectedDeliveryAt) ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if ((o.notes ?? '').trim().isNotEmpty)
                      Text(
                        '${l10n.prepNotes}: ${o.notes!.trim()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
            if (hasPrep || hasDel) ...[
              const SizedBox(height: AppSpacing.space2),
              if (wide)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (hasPrep)
                        Expanded(
                          child: _buildPrepLeg(context),
                        ),
                      if (hasPrep && hasDel) const SizedBox(width: 10),
                      if (hasDel)
                        Expanded(
                          child: _buildDelLeg(context),
                        ),
                    ],
                  ),
                )
              else ...[
                if (hasPrep) _buildPrepLeg(context),
                if (hasPrep && hasDel) const SizedBox(height: 10),
                if (hasDel) _buildDelLeg(context),
              ],
            ],
          ],
        ),
    );
  }

  static Widget _legPanelShell(Color backgroundColor, Widget child) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildPrepLeg(BuildContext context) {
    final prep = item.preparation!;
    final isMine =
        isFulfillmentLegMine(prep.assignedUserId, currentUserId);
    final panel = _PrepPanel(
      preparation: prep,
      l10n: l10n,
      hideTitle: !collapseInactiveLegs || isMine ? false : true,
      onOpen: onOpenPrep,
    );
    if (!collapseInactiveLegs || isMine) {
      return _legPanelShell(const Color(0xFFE8F8EE), panel);
    }
    return _CollapsibleFulfillmentLeg(
      title: l10n.prepTitle,
      subtitle: fulfillmentLegSubtitle(
        l10n,
        assignedUserId: prep.assignedUserId,
        assigneeName: prep.assignedUser?.name,
      ),
      trailing: StatusBadge(
        label: preparationStatusLabel(prep.status, l10n),
        tone: preparationStatusTone(prep.status),
      ),
      backgroundColor: const Color(0xFFE8F8EE),
      initiallyExpanded: false,
      child: panel,
    );
  }

  Widget _buildDelLeg(BuildContext context) {
    final del = item.delivery!;
    final isMine =
        isFulfillmentLegMine(del.assignedUserId, currentUserId);
    final panel = _DelPanel(
      delivery: del,
      l10n: l10n,
      hideTitle: !collapseInactiveLegs || isMine ? false : true,
      onOpen: onOpenDelivery,
    );
    if (!collapseInactiveLegs || isMine) {
      return _legPanelShell(const Color(0xFFE8F0FE), panel);
    }
    return _CollapsibleFulfillmentLeg(
      title: l10n.deliveryTitle,
      subtitle: fulfillmentLegSubtitle(
        l10n,
        assignedUserId: del.assignedUserId,
        assigneeName: del.assignedUser?.name,
      ),
      trailing: StatusBadge(
        label: deliveryStatusLabel(del.status, l10n),
        tone: deliveryStatusTone(del.status),
      ),
      backgroundColor: const Color(0xFFE8F0FE),
      initiallyExpanded: false,
      child: panel,
    );
  }

  String _saleStatusVi(String s, AppLocalizations l10n) {
    switch (s) {
      case 'draft':
        return l10n.ordersStatusDraft;
      case 'confirmed':
        return l10n.ordersStatusConfirmed;
      case 'delivery':
        return l10n.ordersStatusDelivery;
      case 'completed':
        return l10n.ordersStatusCompleted;
      case 'cancelled':
        return l10n.ordersStatusCancelled;
      case 'refund':
        return l10n.ordersStatusRefund;
      default:
        return s;
    }
  }
}

class _CollapsibleFulfillmentLeg extends StatefulWidget {
  const _CollapsibleFulfillmentLeg({
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.initiallyExpanded,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Color backgroundColor;
  final bool initiallyExpanded;
  final Widget child;
  final Widget? trailing;

  @override
  State<_CollapsibleFulfillmentLeg> createState() =>
      _CollapsibleFulfillmentLegState();
}

class _CollapsibleFulfillmentLegState extends State<_CollapsibleFulfillmentLeg> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(_CollapsibleFulfillmentLeg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyExpanded != widget.initiallyExpanded &&
        widget.initiallyExpanded) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) widget.child,
        ],
      ),
    );
  }
}

class _PrepPanel extends StatelessWidget {
  const _PrepPanel({
    required this.preparation,
    required this.l10n,
    this.hideTitle = false,
    required this.onOpen,
  });

  final PreparationOrderPublic preparation;
  final AppLocalizations l10n;
  final bool hideTitle;
  final void Function(String id) onOpen;

  String? get _assigneeName {
    final n = preparation.assignedUser?.name.trim();
    if (n != null && n.isNotEmpty) return n;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final assignee = _assigneeName;
    final statusBadge = StatusBadge(
      label: preparationStatusLabel(preparation.status, l10n),
      tone: preparationStatusTone(preparation.status),
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => onOpen(preparation.id),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hideTitle)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.prepTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  statusBadge,
                ],
              ),
            if (!hideTitle) const SizedBox(height: 4),
            Text(
              '${l10n.prepAssignee}: ${assignee ?? l10n.fulfillmentLegUnassigned}',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if ((preparation.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.prepNotes}: ${preparation.notes!.trim()}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DelPanel extends StatelessWidget {
  const _DelPanel({
    required this.delivery,
    required this.l10n,
    this.hideTitle = false,
    required this.onOpen,
  });

  final DeliveryPublic delivery;
  final AppLocalizations l10n;
  final bool hideTitle;
  final void Function(String id) onOpen;

  String? get _assigneeName {
    final n = delivery.assignedUser?.name.trim();
    if (n != null && n.isNotEmpty) return n;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final assignee = _assigneeName;
    final scheduledLabel = deliveryScheduledFormatted(delivery.scheduledAt);
    final statusBadge = StatusBadge(
      label: deliveryStatusLabel(delivery.status, l10n),
      tone: deliveryStatusTone(delivery.status),
    );
    return Padding(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => onOpen(delivery.id),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!hideTitle)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      l10n.deliveryTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  statusBadge,
                ],
              ),
            if (!hideTitle) const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${l10n.deliveryAssignee}: ${assignee ?? l10n.fulfillmentLegUnassigned}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (scheduledLabel != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    scheduledLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ],
              ],
            ),
            if ((delivery.deliveryNote ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.deliveryNote}: ${delivery.deliveryNote!.trim()}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
