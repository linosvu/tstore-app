import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/support_ticket.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/support_tickets_provider.dart';
import 'package:tstore/widgets/ui/app_search_bar.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';
import 'package:tstore/widgets/ui/list_skeleton.dart';
import 'package:tstore/widgets/ui/status_badge.dart';
import 'package:tstore/widgets/ui/ts_dropdown_field.dart';

import '../repair/repair_ui.dart';
import 'create_support_ticket_screen.dart';
import 'support_ticket_detail_screen.dart';

class SupportTicketsListScreen extends StatefulWidget {
  const SupportTicketsListScreen({
    super.key,
    this.initialStatusFilter,
    this.initialUnassigned = false,
    this.embedded = false,
  });

  final String? initialStatusFilter;
  final bool initialUnassigned;
  final bool embedded;

  @override
  State<SupportTicketsListScreen> createState() => _SupportTicketsListScreenState();
}

class _SupportTicketsListScreenState extends State<SupportTicketsListScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<SupportTicketsProvider>();
      if (!_elevated()) p.setScope('mine');
      if (widget.initialUnassigned) {
        p.setUnassignedFilter(true);
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
    final p = context.read<SupportTicketsProvider>();
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      if (!p.isLoading && !p.isLoadingMore && p.page < p.totalPages) {
        p.load(reset: false);
      }
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const CreateSupportTicketScreen()),
    );
    if (created == true && mounted) {
      context.read<SupportTicketsProvider>().load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prov = context.watch<SupportTicketsProvider>();
    final body = _buildBody(l10n, prov);

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
              label: Text(l10n.supportTicketCreate),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportTicketsNav)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.supportTicketCreate),
      ),
      body: body,
    );
  }

  Widget _buildBody(AppLocalizations l10n, SupportTicketsProvider prov) {
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
                hintText: l10n.supportSearchHint,
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
          SliverToBoxAdapter(child: _filterChips(prov)),
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
              child: EmptyState(message: l10n.supportListEmpty),
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
                    final item = prov.items[i];
                    return _TicketCard(
                      item: item,
                      onTap: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SupportTicketDetailScreen(ticketId: item.id),
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

  Widget _filterChips(SupportTicketsProvider prov) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          FilterChip(
            label: const Text('Tất cả'),
            selected: prov.statusFilter == null && !prov.unassignedFilter,
            onSelected: (_) {
              prov.setStatusFilter(null);
              prov.load(reset: true);
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            label: const Text('Chưa phân công'),
            selected: prov.unassignedFilter,
            onSelected: (_) {
              prov.setUnassignedFilter(true);
              prov.load(reset: true);
            },
          ),
          for (final st in ['open', 'waiting_customer', 'in_progress'])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: FilterChip(
                label: Text(supportStatusLabel(st)),
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

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.item, required this.onTap});

  final SupportTicketPublic item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                  child: Text(
                    item.subject,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                StatusBadge(
                  label: supportStatusLabel(item.status),
                  tone: supportStatusTone(item.status),
                ),
              ],
            ),
            Text('#${item.ticketCode}', style: Theme.of(context).textTheme.labelSmall),
            Text(item.customerName),
            const SizedBox(height: 4),
            Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                StatusBadge(
                  label: supportCategoryLabel(item.category),
                  tone: StatusBadgeTone.neutral,
                ),
                StatusBadge(
                  label: repairPriorityLabel(item.priority, AppLocalizations.of(context)),
                  tone: repairPriorityTone(item.priority),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
