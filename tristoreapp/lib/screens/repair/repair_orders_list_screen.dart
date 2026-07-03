import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/repair_order.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/repair_orders_provider.dart';
import 'package:tstore/widgets/ui/app_search_bar.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/list_skeleton.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import 'create_repair_order_screen.dart';
import 'repair_order_detail_screen.dart';
import 'repair_ui.dart';

class RepairOrdersListScreen extends StatefulWidget {
  const RepairOrdersListScreen({
    super.key,
    this.initialStatusFilter,
    this.initialOverdue = false,
    this.embedded = false,
  });

  final String? initialStatusFilter;
  final bool initialOverdue;
  final bool embedded;

  @override
  State<RepairOrdersListScreen> createState() => _RepairOrdersListScreenState();
}

class _RepairOrdersListScreenState extends State<RepairOrdersListScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<RepairOrdersProvider>();
      final elevated = _elevated();
      if (!elevated) p.setScope('mine');
      if (widget.initialOverdue) {
        p.setOverdueFilter(true);
      } else if (widget.initialStatusFilter != null) {
        p.setStatusFilter(widget.initialStatusFilter);
      }
      p.load(reset: true);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _elevated() {
    final role = context.read<AuthProvider>().user?.role;
    return role == 'admin' || role == 'manager';
  }

  void _onScroll() {
    final p = context.read<RepairOrdersProvider>();
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!p.isLoading && !p.isLoadingMore && p.page < p.totalPages) {
        p.load(reset: false);
      }
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const CreateRepairOrderScreen()),
    );
    if (created == true && mounted) {
      context.read<RepairOrdersProvider>().load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prov = context.watch<RepairOrdersProvider>();

    final body = _buildBody(context, l10n, prov);

    if (widget.embedded) {
      return Stack(
        children: [
          body,
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.repairSubmit),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.ordersSubTabRepair)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.repairSubmit),
      ),
      body: body,
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    RepairOrdersProvider prov,
  ) {
    if (prov.error != null && prov.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        children: [
          ErrorBanner(
            message: prov.error!,
            retryLabel: l10n.productsRetry,
            onRetry: () => prov.load(reset: true),
          ),
        ],
      );
    }
    if (prov.isLoading && prov.items.isEmpty) {
      return const ListSkeleton(rows: 5, variant: ListSkeletonVariant.orderRow);
    }

    return RefreshIndicator(
      onRefresh: () => prov.load(reset: true),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.space2,
                AppSpacing.screenHorizontal,
                8,
              ),
              child: AppSearchBar(
                controller: _searchCtrl,
                hintText: l10n.repairSearchHint,
                onChanged: (v) {
                  prov.setSearch(v);
                  prov.load(reset: true);
                },
                onClear: () {
                  prov.setSearch('');
                  prov.load(reset: true);
                },
              ),
            ),
          ),
          SliverToBoxAdapter(child: _filterChips(l10n, prov)),
          if (_elevated())
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                  vertical: 4,
                ),
                child: TsDropdownField<String>(
                  value: prov.listScope,
                  labelText: l10n.fulfillmentScopeLabel,
                  items: const ['mine', 'all'],
                  itemLabel: (v) => v == 'mine' ? 'Của tôi' : 'Toàn hệ thống',
                  onChanged: (v) {
                    if (v == null) return;
                    prov.setScope(v);
                    prov.load(reset: true);
                  },
                ),
              ),
            ),
          if (prov.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(message: l10n.repairListEmpty),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                0,
                AppSpacing.screenHorizontal,
                88,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    if (i >= prov.items.length) {
                      return prov.isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : const SizedBox.shrink();
                    }
                    return _RepairListCard(
                      item: prov.items[i],
                      l10n: l10n,
                      onTap: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RepairOrderDetailScreen(
                              orderId: prov.items[i].id,
                            ),
                          ),
                        );
                        if (context.mounted) prov.load(reset: true);
                      },
                    );
                  },
                  childCount: prov.items.length + (prov.isLoadingMore ? 1 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChips(AppLocalizations l10n, RepairOrdersProvider prov) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tất cả'),
            selected: prov.statusFilter == null && !prov.overdueFilter,
            onSelected: (_) {
              prov.setStatusFilter(null);
              prov.load(reset: true);
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Quá hạn'),
            selected: prov.overdueFilter,
            onSelected: (_) {
              prov.setOverdueFilter(true);
              prov.load(reset: true);
            },
          ),
          for (final st in ['waiting_parts', 'done', 'received'])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                label: Text(repairStatusLabel(st, l10n)),
                selected: prov.statusFilter == st,
                onSelected: (_) {
                  prov.setStatusFilter(st);
                  prov.load(reset: true);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RepairListCard extends StatelessWidget {
  const _RepairListCard({
    required this.item,
    required this.l10n,
    required this.onTap,
  });

  final RepairOrderPublic item;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurfaceCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (item.customer?.isVip == true) ...[
                        const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFA000)),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          item.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(
                  label: repairStatusLabel(item.status, l10n),
                  tone: repairStatusTone(item.status),
                ),
              ],
            ),
            Text(
              '#${item.displayCode}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (item.customerPhone != null && item.customerPhone!.isNotEmpty)
              Row(
                children: [
                  Expanded(child: Text(item.customerPhone!)),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: item.customerPhone!));
                      AppMessenger.showSnackBar(
                        context,
                        const SnackBar(content: Text('Đã sao chép SĐT')),
                      );
                    },
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(item.itemDescription, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                StatusBadge(
                  label: repairPriorityLabel(item.priority, l10n),
                  tone: repairPriorityTone(item.priority),
                ),
                if (item.isOverdue)
                  const StatusBadge(label: 'Quá hạn trả', tone: StatusBadgeTone.error),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.repairReceivedDate}: ${item.receivedDate ?? '—'} · '
              '${l10n.repairPromisedDate}: ${item.promisedDate ?? '—'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
