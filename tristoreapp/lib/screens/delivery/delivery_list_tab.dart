import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/delivery.dart';
import 'package:tstore/providers/delivery_provider.dart';
import 'package:tstore/screens/delivery/delivery_compact_card.dart';
import 'package:tstore/screens/delivery/delivery_detail_screen.dart';
import 'package:tstore/screens/delivery/delivery_ui.dart';
import 'package:tstore/widgets/ui/empty_state.dart';
import 'package:tstore/widgets/ui/error_banner.dart';

class DeliveryListTab extends StatefulWidget {
  const DeliveryListTab({
    super.key,
    this.listType = DeliveryListType.mine,
  });

  final DeliveryListType listType;

  @override
  State<DeliveryListTab> createState() => _DeliveryListTabState();
}

class _DeliveryListTabState extends State<DeliveryListTab> {
  /// `null` = tất cả trạng thái.
  String? _statusFilter;
  static const _todayStatuses = {'pending', 'delivering'};

  bool _matchesStatusFilter(String status, String? filter) {
    if (filter == null) return true;
    if (filter == 'pending') {
      return status == 'pending' ||
          status == 'awaiting_confirm' ||
          status == 'preparing' ||
          status == 'ready';
    }
    return status == filter;
  }

  List<DeliveryPublic> _items(DeliveryProvider p) {
    switch (widget.listType) {
      case DeliveryListType.mine:
        return p.myDeliveries;
      case DeliveryListType.created:
        return p.createdDeliveries;
    }
  }

  bool _loading(DeliveryProvider p) {
    switch (widget.listType) {
      case DeliveryListType.mine:
        return p.isLoadingMine;
      case DeliveryListType.created:
        return p.isLoadingCreated;
    }
  }

  String? _error(DeliveryProvider p) {
    switch (widget.listType) {
      case DeliveryListType.mine:
        return p.errorMine;
      case DeliveryListType.created:
        return p.errorCreated;
    }
  }

  Future<void> _reload(DeliveryProvider p) {
    switch (widget.listType) {
      case DeliveryListType.mine:
        return p.loadMine();
      case DeliveryListType.created:
        return p.loadCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Consumer<DeliveryProvider>(
      builder: (context, p, _) {
        final items = _items(p);
        final isLoading = _loading(p);
        final err = _error(p);
        if (isLoading && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (err != null && items.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              ErrorBanner(message: err),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _reload(p),
                child: Text(l10n.deliveryRetry),
              ),
            ],
          );
        }
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.local_shipping_outlined,
            message: widget.listType == DeliveryListType.mine
                ? l10n.deliveryEmpty
                : l10n.deliveryCreatedEmpty,
          );
        }

        final filtered = items
            .where((d) => _matchesStatusFilter(d.status, _statusFilter))
            .toList();
        final todayItems =
            filtered.where((e) => _todayStatuses.contains(e.status)).toList();
        final nextItems =
            filtered.where((e) => !_todayStatuses.contains(e.status)).toList();

        return RefreshIndicator(
          onRefresh: () => _reload(p),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.space2,
                    AppSpacing.screenHorizontal,
                    AppSpacing.space2,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text(l10n.deliveryFilterAll),
                          selected: _statusFilter == null,
                          onSelected: (v) {
                            if (v) setState(() => _statusFilter = null);
                          },
                        ),
                        const SizedBox(width: 8),
                        ...kDeliveryMineStatusFilterOrder.map((status) {
                          final selected = _statusFilter == status;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                deliveryStatusLabel(status, l10n),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: deliveryStatusColor(
                                status,
                                Theme.of(context),
                              ).withValues(alpha: 0.22),
                              onSelected: (v) {
                                setState(() {
                                  if (v) {
                                    _statusFilter = status;
                                  } else {
                                    _statusFilter = null;
                                  }
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(AppSpacing.screenHorizontal),
                      child: Text(
                        l10n.deliveryFilterEmpty,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    0,
                    AppSpacing.screenHorizontal,
                    AppSpacing.space2,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _groupDivider(
                          context, l10n.groupTodayCount(todayItems.length)),
                      ...todayItems.map(
                        (d) => DeliveryCompactCard(
                          d: d,
                          l10n: l10n,
                          scheme: scheme,
                          showPriorityBeforeStatus: true,
                          onOpenDetail: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    DeliveryDetailScreen(deliveryId: d.id),
                              ),
                            );
                          },
                        ),
                      ),
                      if (nextItems.isNotEmpty)
                        _groupDivider(context, l10n.groupNext),
                      ...nextItems.map(
                        (d) => DeliveryCompactCard(
                          d: d,
                          l10n: l10n,
                          scheme: scheme,
                          showPriorityBeforeStatus: true,
                          onOpenDetail: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    DeliveryDetailScreen(deliveryId: d.id),
                              ),
                            );
                          },
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _groupDivider(BuildContext context, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(0, AppSpacing.space2, 0, AppSpacing.space2),
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
}

enum DeliveryListType { mine, created }
