import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/utils/app_date_time.dart';
import 'package:tstore/core/constants/routes.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/theme/app_text_styles.dart';
import 'package:tstore/models/sale_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/screens/main_shell.dart';
import 'package:tstore/screens/management/management_date_presets.dart';
import 'package:tstore/screens/orders/sale_order_detail_screen.dart';
import 'package:tstore/screens/orders/sale_order_flow_screen.dart';
import 'package:tstore/screens/delivery/delivery_ui.dart';
import 'package:tstore/widgets/ui/app_search_bar.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/core/theme/app_ui_extension.dart';
import 'package:tstore/widgets/ui/list_skeleton.dart';
import 'package:tstore/widgets/ui/screen_gradient_header.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final List<SaleOrderPublic> _items = [];
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  String? _statusFilter;
  String? _paymentFilter;
  bool _filtersExpanded = false;
  int _scopeSegment = 0;

  static const _primaryStatusFilters = <String?>[null, 'confirmed', 'completed'];
  static const _extraStatusFilters = ['draft', 'delivery', 'refund', 'cancelled'];
  String? _dateFrom;
  String? _dateTo;
  static const _scopeValues = ['all', 'mine'];
  static const _todayDeliveryStatuses = {
    'pending',
    'delivering',
  };

  bool _isStaffOrAbove(BuildContext context) {
    final u = context.read<AuthProvider>().user;
    return u != null &&
        (u.role == 'staff' || u.role == 'admin' || u.role == 'manager');
  }

  void _consumePendingLaunch() {
    final shell = MainShellController.maybeOf(context);
    final launch = shell?.pendingOrdersLaunch;
    if (launch == null) return;
    shell!.pendingOrdersLaunch = null;
    if (launch.status != null) {
      _statusFilter = launch.status;
      if (!_primaryStatusFilters.contains(launch.status)) {
        _filtersExpanded = true;
      }
    }
    if (launch.useListAll && _isStaffOrAbove(context)) {
      _scopeSegment = 0;
    }
  }

  String? _listQueryParam() {
    final scope = _scopeValues[_scopeSegment.clamp(0, _scopeValues.length - 1)];
    if (scope == 'all') {
      return _isStaffOrAbove(context) ? 'all' : null;
    }
    return scope;
  }

  bool get _hasDateFilter =>
      (_dateFrom != null && _dateFrom!.isNotEmpty) ||
      (_dateTo != null && _dateTo!.isNotEmpty);

  @override
  void initState() {
    super.initState();
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

    final auth = context.read<AuthProvider>();
    final q = <String, dynamic>{'page': nextPage, 'limit': 20};
    final listParam = _listQueryParam();
    if (listParam != null) {
      q['list'] = listParam;
    }
    if (_statusFilter != null) q['status'] = _statusFilter;
    if (_paymentFilter != null) q['paymentFilter'] = _paymentFilter;
    final searchTrim = _searchCtrl.text.trim();
    if (searchTrim.isNotEmpty) q['search'] = searchTrim;
    if (_dateFrom != null && _dateFrom!.isNotEmpty) q['from'] = _dateFrom;
    if (_dateTo != null && _dateTo!.isNotEmpty) q['to'] = _dateTo;

    try {
      final res = await auth.api.get<Map<String, dynamic>>(
        '/admin/sale-orders',
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
      final raw = data['items'];
      final list = raw is List
          ? raw
              .map((e) => SaleOrderPublic.fromJson(e as Map<String, dynamic>))
              .toList()
          : <SaleOrderPublic>[];
      final total = (data['total'] as num?)?.toInt() ?? 0;
      final limit = (data['limit'] as num?)?.toInt() ?? 20;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(list);
        } else {
          _items.addAll(list);
        }
        _page = nextPage;
        _totalPages = (total / limit).ceil().clamp(1, 9999);
        _loading = false;
        _loadingMore = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.message ?? 'Lỗi kết nối';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Lỗi không xác định';
      });
    }
  }

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final vn = AppDateTime.toVn(d);
    return '${vn.day.toString().padLeft(2, '0')}/${vn.month.toString().padLeft(2, '0')} ${vn.hour.toString().padLeft(2, '0')}:${vn.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openNewOrder() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const SaleOrderFlowScreen(),
      ),
    );
    if (ok == true && mounted) _load(reset: true);
  }

  void _applyDatePreset(({String? from, String? to}) preset) {
    setState(() {
      _dateFrom = preset.from;
      _dateTo = preset.to;
    });
    _load(reset: true);
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(
              start: DateTime.parse(_dateFrom!),
              end: DateTime.parse(_dateTo!),
            )
          : null,
    );
    if (range == null || !mounted) return;
    final from =
        '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
    final to =
        '${range.end.year}-${range.end.month.toString().padLeft(2, '0')}-${range.end.day.toString().padLeft(2, '0')}';
    setState(() {
      _dateFrom = from;
      _dateTo = to;
    });
    _load(reset: true);
  }

  Future<void> _openDateFilterSheet() async {
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.space2,
                  AppSpacing.screenHorizontal,
                  AppSpacing.space1,
                ),
                child: Text(
                  l10n.ordersDateFilterTitle,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.today_outlined),
                title: Text(l10n.ordersDatePreset1Day),
                onTap: () {
                  Navigator.pop(ctx);
                  _applyDatePreset(ManagementDatePresets.today());
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range_outlined),
                title: Text(l10n.ordersDatePreset1Week),
                onTap: () {
                  Navigator.pop(ctx);
                  _applyDatePreset(ManagementDatePresets.last7Days());
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(l10n.ordersDatePreset1Month),
                onTap: () {
                  Navigator.pop(ctx);
                  _applyDatePreset(ManagementDatePresets.thisMonth());
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_note_outlined),
                title: Text(l10n.ordersDatePreset3Months),
                onTap: () {
                  Navigator.pop(ctx);
                  _applyDatePreset(ManagementDatePresets.last90Days());
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: Text(l10n.ordersDatePresetCustom),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCustomDateRange();
                },
              ),
              if (_hasDateFilter)
                ListTile(
                  leading: Icon(
                    Icons.clear_all_rounded,
                    color: Theme.of(ctx).colorScheme.error,
                  ),
                  title: Text(
                    l10n.ordersDateFilterClear,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _applyDatePreset(ManagementDatePresets.all());
                  },
                ),
              const SizedBox(height: AppSpacing.space2),
            ],
          ),
        );
      },
    );
  }

  Future<void> _assignOrderFromBoard(SaleOrderPublic o) async {
    final l10n = AppLocalizations.of(context);
    try {
      final auth = context.read<AuthProvider>();
      await auth.api.post<Map<String, dynamic>>(
        '/admin/sale-orders/${o.id}/assign',
      );
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.ordersAssignToMeSuccess)),
      );
      _load(reset: true);
    } on DioException catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(e.message ?? l10n.error)),
      );
    }
  }

  Future<void> _openOrder(SaleOrderPublic o) async {
    if (o.status == 'draft') {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => SaleOrderFlowScreen(initialOrderId: o.id),
        ),
      );
      if (ok == true && mounted) _load(reset: true);
    } else {
      final updated = await Navigator.push<SaleOrderPublic?>(
        context,
        MaterialPageRoute<SaleOrderPublic?>(
          builder: (_) => SaleOrderDetailScreen(orderId: o.id),
        ),
      );
      if (!mounted || updated == null) return;
      setState(() {
        final idx = _items.indexWhere((e) => e.id == updated.id);
        if (idx >= 0) _items[idx] = updated;
      });
    }
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
              title: l10n.ordersNav,
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
                    Navigator.pushReplacementNamed(
                      context,
                      AppRoutes.home,
                    );
                  }
                },
              ),
              actions: [
                IconButton(
                  tooltip: l10n.reload,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.onPrimary,
                  ),
                  onPressed: _loading ? null : () => _load(reset: true),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _openNewOrder,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                  label: Text(
                    l10n.ordersCreate,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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
                    label: Text(l10n.ordersScopeAll),
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text(l10n.ordersScopeMine),
                    icon: const Icon(Icons.person_outline, size: 18),
                  ),
                ],
                selected: {_scopeSegment},
                onSelectionChanged: (Set<int> next) {
                  final idx = next.first;
                  if (idx == _scopeSegment) return;
                  setState(() => _scopeSegment = idx);
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
              child: Row(
                children: [
                  Expanded(
                    child: AppSearchBar(
                      controller: _searchCtrl,
                      hintText: l10n.ordersSearchHint,
                      onChanged: (_) => _onSearchChanged(),
                      onClear: () => _onSearchChanged(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space1),
                  IconButton(
                    tooltip: l10n.ordersDateFilterTitle,
                    onPressed: _openDateFilterSheet,
                    icon: Icon(
                      Icons.filter_list_outlined,
                      size: 22,
                      color: _hasDateFilter
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // ─── Filter chips ───────────────────────────────────────────────
            SizedBox(
              height: 48,
              child: _buildFilterChipRow(l10n, scheme),
            ),
            if (_loading && _items.isEmpty)
              const Divider(height: 2)
            else if (_loading || _loadingMore)
              const LinearProgressIndicator(minHeight: 2)
            else
              const Divider(height: 2),
            // ─── Body ───────────────────────────────────────────────────────
            Expanded(
              child: _buildBody(l10n),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasHiddenFilterActive {
    if (_statusFilter == null) return false;
    return !_primaryStatusFilters.contains(_statusFilter);
  }

  String _statusLabel(AppLocalizations l10n, String? status) {
    switch (status) {
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
        return l10n.ordersFilterAll;
    }
  }

  Widget _buildFilterChipRow(AppLocalizations l10n, ColorScheme scheme) {
    final pad = const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenHorizontal,
      vertical: AppSpacing.space1,
    );
    final gap = const SizedBox(width: AppSpacing.space2);

    Widget spaced(Iterable<Widget> items) {
      final list = items.toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Row(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) gap,
            list[i],
          ],
        ],
      );
    }

    final primaryChips = _primaryStatusFilters.map(
      (s) => _chip(s, _statusLabel(l10n, s), scheme),
    );

    if (!_filtersExpanded) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: pad,
        child: spaced([
          ...primaryChips,
          _paymentChip('unpaid', l10n.ordersFilterPaymentUnpaid, scheme),
          _filtersToggleChip(
            l10n.ordersFilterShowMore,
            Icons.add_rounded,
            scheme,
            highlighted: _hasHiddenFilterActive,
            onTap: () => setState(() => _filtersExpanded = true),
          ),
        ]),
      );
    }

    final extraChips = _extraStatusFilters.map(
      (s) => _chip(s, _statusLabel(l10n, s), scheme),
    );

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: pad,
      children: [
        ...primaryChips.expand((w) => [w, gap]),
        ...extraChips.expand((w) => [w, gap]),
        _paymentChip('unpaid', l10n.ordersFilterPaymentUnpaid, scheme),
        gap,
        _filtersToggleChip(
          l10n.ordersFilterShowLess,
          Icons.remove_rounded,
          scheme,
          onTap: () => setState(() => _filtersExpanded = false),
        ),
      ],
    );
  }

  Widget _filtersToggleChip(
    String label,
    IconData icon,
    ColorScheme scheme, {
    required VoidCallback onTap,
    bool highlighted = false,
  }) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: highlighted ? AppColors.primary : scheme.onSurfaceVariant,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: highlighted ? AppColors.primary : scheme.onSurface,
        ),
      ),
      backgroundColor: highlighted
          ? AppColors.primary.withValues(alpha: 0.12)
          : scheme.surfaceContainerHighest,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onPressed: onTap,
    );
  }

  Widget _chip(String? value, String label, ColorScheme scheme) {
    final selected = _statusFilter == value;
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
        setState(() => _statusFilter = sel ? value : null);
        _load(reset: true);
      },
    );
  }

  Widget _paymentChip(String value, String label, ColorScheme scheme) {
    final selected = _paymentFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AppColors.warning : scheme.onSurface,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onSelected: (sel) {
        setState(() => _paymentFilter = sel ? value : null);
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
        rows: 8,
        variant: ListSkeletonVariant.orderRow,
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

    bool isTodayGroup(SaleOrderPublic o) {
      final ds = o.linkedDeliveryStatus?.trim();
      if (ds != null && ds.isNotEmpty) return _todayDeliveryStatuses.contains(ds);
      if (o.status == 'confirmed' || o.status == 'delivery') return true;
      return false;
    }

    final todayItems = _items.where(isTodayGroup).toList();
    final nextItems = _items.where((o) => !isTodayGroup(o)).toList();
    final grouped = <_OrderListEntry>[
      _OrderHeaderEntry(l10n.groupTodayCount(todayItems.length)),
      ...todayItems.map((o) => _OrderItemEntry(o)),
      if (nextItems.isNotEmpty) _OrderHeaderEntry(l10n.groupNext),
      ...nextItems.map((o) => _OrderItemEntry(o)),
    ];

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.space2,
          AppSpacing.screenHorizontal,
          AppSpacing.space4,
        ),
        itemCount: grouped.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == grouped.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final e = grouped[i];
          if (e is _OrderHeaderEntry) {
            return _groupDivider(e.label);
          }
          final o = (e as _OrderItemEntry).order;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space2),
            child: _OrderRowCard(
              order: o,
              amountText: _formatMoney(o.subtotal),
              amountDueText: o.amountDue > 0 ? _formatMoney(o.amountDue) : null,
              subtitle: (o.orderSource == 'kiotviet' &&
                      o.kiotVietPurchaseDate != null)
                  ? _shortDate(o.kiotVietPurchaseDate!)
                  : _shortDate(o.createdAt),
              onTap: () => _openOrder(o),
              showAssignButton:
                  _scopeSegment == 0 && o.isOnManagementBoard,
              assignLabel: l10n.ordersAssignToMe,
              onAssign: () => _assignOrderFromBoard(o),
            ),
          );
        },
      ),
    );
  }

  Widget _groupDivider(String label) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.space2, 0, AppSpacing.space2),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space2),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }

  String _formatMoney(int v) {
    return '${v.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        )} đ';
  }
}

sealed class _OrderListEntry {
  const _OrderListEntry();
}

class _OrderHeaderEntry extends _OrderListEntry {
  const _OrderHeaderEntry(this.label);
  final String label;
}

class _OrderItemEntry extends _OrderListEntry {
  const _OrderItemEntry(this.order);
  final SaleOrderPublic order;
}

class _OrderRowCard extends StatelessWidget {
  const _OrderRowCard({
    required this.order,
    required this.amountText,
    this.amountDueText,
    required this.subtitle,
    required this.onTap,
    this.showAssignButton = false,
    this.assignLabel,
    this.onAssign,
  });

  final SaleOrderPublic order;
  final String amountText;
  final String? amountDueText;
  final String subtitle;
  final VoidCallback onTap;
  final bool showAssignButton;
  final String? assignLabel;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final ui = context.appUi;
    final expectedDelivery =
        orderExpectedDeliveryCompact(order.expectedDeliveryAt);
    final managedByName = (order.managedBy?.name ?? '').trim();
    final createdByName = (order.createdBy?.name ?? '').trim();
    final notesText = (order.notes ?? '').trim();
    return Material(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ui.radiusLg),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ui.radiusLg),
            boxShadow: ui.softShadow,
          ),
          child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.cardInnerLg,
            vertical: AppSpacing.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Phần trên: thông tin đơn (trái) + số tiền (phải)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dòng 1: Mã đơn + nút copy ngay kề
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '#${order.displayCode}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 2),
                            Tooltip(
                              message: l10n.copyText,
                              child: Semantics(
                                button: true,
                                label: l10n.copyText,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: order.id),
                                    );
                                    if (!context.mounted) return;
                                    AppMessenger.showSnackBar(
                                      context,
                                      SnackBar(
                                        content: Text(l10n.ordersOrderIdCopied),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                    child: Icon(
                                      Icons.copy_outlined,
                                      size: 15,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.space1),
                        Text(
                          '${l10n.ordersOrderShort} · $subtitle',
                          style: AppTextStyles.dataSecondary(context)
                              .copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (order.customer?.isVip == true) ...[
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Color(0xFFFFA000),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                order.customer == null
                                    ? '—'
                                    : (order.customer!.phone?.trim().isNotEmpty ??
                                            false)
                                        ? '${order.customer!.name} · ${order.customer!.phone!.trim()}'
                                        : order.customer!.name,
                                style:
                                    AppTextStyles.dataSecondary(context)
                                        .copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (createdByName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 13,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  createdByName,
                                  style: AppTextStyles.dataSecondary(context)
                                      .copyWith(
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.space2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (amountDueText != null) ...[
                        StatusBadge(
                          label: '${l10n.ordersAmountDue}: $amountDueText',
                          tone: StatusBadgeTone.warning,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            amountText,
                            style: AppTextStyles.amount(context).copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (expectedDelivery != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'DK: $expectedDelivery',
                              style: AppTextStyles.dataSecondary(context)
                                  .copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (notesText.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.space2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          notesText,
                          style: AppTextStyles.dataSecondary(context)
                              .copyWith(
                            color: scheme.onSurface,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.space1),
              _OrderProgressBar(
                orderStatus: order.status,
                preparationStatus: order.linkedPreparationStatus,
                deliveryStatus: order.linkedDeliveryStatus,
                amountDue: order.amountDue,
                managedByName:
                    managedByName.isNotEmpty ? managedByName : null,
                preparationAssignedName: order.linkedPreparationAssignedName,
                deliveryAssignedName: order.linkedDeliveryAssignedName,
                l10n: l10n,
              ),
              if (showAssignButton && onAssign != null) ...[
                const SizedBox(height: AppSpacing.space1),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 12,
                      ),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onAssign,
                    child: Text(assignLabel ?? l10n.ordersAssignToMe),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

enum _FlowStepState { pending, active, done, failed }

class _OrderProgressBar extends StatelessWidget {
  const _OrderProgressBar({
    required this.orderStatus,
    required this.preparationStatus,
    required this.deliveryStatus,
    required this.amountDue,
    required this.l10n,
    this.managedByName,
    this.preparationAssignedName,
    this.deliveryAssignedName,
  });

  final String orderStatus;
  final String? preparationStatus;
  final String? deliveryStatus;
  final int amountDue;
  final AppLocalizations l10n;
  final String? managedByName;
  final String? preparationAssignedName;
  final String? deliveryAssignedName;

  _FlowStepState _orderStepState() {
    if (orderStatus == 'cancelled' || orderStatus == 'refund') {
      return _FlowStepState.failed;
    }
    if (orderStatus == 'draft') return _FlowStepState.active;
    return _FlowStepState.done;
  }

  _FlowStepState _prepStepState() {
    final s = preparationStatus?.trim();
    if (s == null || s.isEmpty) return _FlowStepState.pending;
    if (s == 'cancelled') return _FlowStepState.failed;
    if (s == 'ready' || s == 'done') return _FlowStepState.done;
    if (s == 'pending' || s == 'in_progress') return _FlowStepState.active;
    return _FlowStepState.pending;
  }

  /// Suy trạng thái giao từ deliveryStatus (đơn nội bộ) hoặc orderStatus
  /// (đơn KiotViet không có Delivery entity).
  String? _effectiveDeliveryStatus() {
    if (deliveryStatus != null) return deliveryStatus;
    switch (orderStatus) {
      case 'delivery':
        return 'delivering';
      case 'completed':
        return 'completed';
      case 'cancelled':
      case 'refund':
        return 'cancelled';
      default:
        return null;
    }
  }

  _FlowStepState _deliveryStepState() {
    final s = _effectiveDeliveryStatus()?.trim();
    if (s == null || s.isEmpty) return _FlowStepState.pending;
    if (s == 'failed' || s == 'cancelled') return _FlowStepState.failed;
    if (s == 'completed') return _FlowStepState.done;
    if (s == 'pending' ||
        s == 'awaiting_confirm' ||
        s == 'preparing' ||
        s == 'ready' ||
        s == 'delivering') {
      return _FlowStepState.active;
    }
    return _FlowStepState.pending;
  }

  _FlowStepState _paymentStepState() {
    // Đơn hoàn thành → tất cả bước đều xong, kể cả thanh toán.
    if (orderStatus == 'completed') return _FlowStepState.done;
    if (orderStatus == 'cancelled' || orderStatus == 'refund') {
      return _FlowStepState.failed;
    }
    if (amountDue <= 0) return _FlowStepState.done;
    return _FlowStepState.active;
  }

  @override
  Widget build(BuildContext context) {
    final steps = <(String, _FlowStepState)>[
      (l10n.ordersOrderShort, _orderStepState()),
      (l10n.prepNav, _prepStepState()),
      (l10n.deliveryNav, _deliveryStepState()),
      (l10n.saleOrderStep3Title, _paymentStepState()),
    ];
    final scheme = Theme.of(context).colorScheme;

    Color colorOf(_FlowStepState state) {
      switch (state) {
        case _FlowStepState.done:
          return const Color(0xFF22C55E);
        case _FlowStepState.active:
          return const Color(0xFF5C60E6);
        case _FlowStepState.failed:
          return scheme.error;
        case _FlowStepState.pending:
          return scheme.outlineVariant;
      }
    }

    final connectorColor = (steps[0].$2 == _FlowStepState.pending)
        ? scheme.outlineVariant
        : const Color(0xFF5C60E6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 26,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = steps.length;
              final stepWidth = constraints.maxWidth / count;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: stepWidth / 2,
                    right: stepWidth / 2,
                    top: 11,
                    child: Container(height: 2, color: connectorColor),
                  ),
                  Row(
                    children: List.generate(count, (i) {
                      final state = steps[i].$2;
                      final color = colorOf(state);
                      return Expanded(
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: state == _FlowStepState.pending
                                  ? Colors.transparent
                                  : color,
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Center(
                              child: state == _FlowStepState.done
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '${i + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: state == _FlowStepState.pending
                                                ? color
                                                : Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            // Bước Đơn: người nhận; Chuẩn bị / Giao hàng: NV được gán
            final assignedName = switch (i) {
              0 => managedByName?.trim(),
              1 => preparationAssignedName?.trim(),
              2 => deliveryAssignedName?.trim(),
              _ => null,
            };
            return Expanded(
              child: Column(
                children: [
                  Text(
                    s.$1,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (assignedName != null && assignedName.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      assignedName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontSize: 9,
                          ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
