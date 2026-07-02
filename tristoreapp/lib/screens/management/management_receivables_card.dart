import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/theme/app_ui_extension.dart';
import 'package:tstore/models/management_entity.dart';
import 'package:tstore/models/management_filters.dart';
import 'package:tstore/models/management_receivables_summary.dart';
import 'package:tstore/providers/management_provider.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';

import 'management_results_screen.dart';

class ManagementReceivablesCard extends StatefulWidget {
  const ManagementReceivablesCard({
    super.key,
    required this.mgmt,
    required this.filters,
    required this.onFilterTap,
  });

  final ManagementProvider mgmt;
  final ManagementFilters filters;
  final VoidCallback onFilterTap;

  @override
  ManagementReceivablesCardState createState() =>
      ManagementReceivablesCardState();
}

class ManagementReceivablesCardState extends State<ManagementReceivablesCard> {
  ManagementReceivablesSummary? _summary;
  String? _error;
  bool _loading = true;

  @override
  void didUpdateWidget(ManagementReceivablesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters) {
      _load();
    }
  }

  Future<void> load() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await widget.mgmt.fetchReceivablesSummary(
        filters: widget.filters,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ManagementProvider.dioMessage(e) ?? 'Lỗi';
        _loading = false;
      });
    }
  }

  void _openResults({
    required ManagementFilters chipFilters,
    required String title,
  }) {
    final merged = widget.filters.copyWith(
      paymentFilter: chipFilters.paymentFilter,
      hasScheduledDelivery: chipFilters.hasScheduledDelivery,
      clearPaymentFilter: chipFilters.paymentFilter == null,
      clearScheduled: chipFilters.hasScheduledDelivery != true,
    );
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ManagementResultsScreen(
          entity: ManagementEntity.saleOrders,
          filters: merged,
          titleOverride: title,
        ),
      ),
    );
  }

  String _formatMoney(int? value) {
    if (_loading || value == null) return '—';
    final f = NumberFormat('#,###', 'vi_VN');
    return '${f.format(value)} đ';
  }

  String _count(int? value) {
    if (_loading) return '—';
    return '${value ?? 0}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ui = context.appUi;
    final unpaid = _summary?.unpaid;

    return AppSurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.managementCardReceivables,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (widget.filters.hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.filters.activeCount}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: l10n.managementFilterTitle,
                onPressed: widget.onFilterTap,
                icon: const Icon(Icons.filter_list_rounded),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.space2),
            Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
            TextButton(onPressed: _load, child: Text(l10n.productsRetry)),
          ] else if (_loading)
            const SizedBox(
              height: 168,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const SizedBox(height: AppSpacing.space2),
            Material(
              color: AppColors.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(ui.radiusSm),
              child: InkWell(
                onTap: () => _openResults(
                  chipFilters: const ManagementFilters(paymentFilter: 'unpaid'),
                  title: l10n.managementReceivableUnpaid,
                ),
                borderRadius: BorderRadius.circular(ui.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.warning,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_count(unpaid?.count)} ${l10n.managementReceivableUnpaidOrders}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.managementReceivableUnpaidHint,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            l10n.managementReceivableTotalDue,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatMoney(unpaid?.totalAmountDue),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.warning,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.space2),
            Wrap(
              spacing: AppSpacing.space2,
              runSpacing: AppSpacing.space2,
              children: [
                ReceivableMetricChip(
                  label: l10n.managementReceivableScheduledDelivery,
                  hint: l10n.managementReceivableScheduledDeliveryHint,
                  count: _count(_summary?.scheduledDelivery.count),
                  amount: null,
                  color: AppColors.primary,
                  icon: Icons.event_outlined,
                  onTap: () => _openResults(
                    chipFilters: const ManagementFilters(
                      hasScheduledDelivery: true,
                    ),
                    title: l10n.managementReceivableScheduledDelivery,
                  ),
                ),
                ReceivableMetricChip(
                  label: l10n.managementReceivablePendingApproval,
                  hint: l10n.managementReceivablePendingApprovalHint,
                  count: _count(_summary?.pendingApproval.count),
                  amount: _formatMoney(
                    _summary?.pendingApproval.totalPendingAmount,
                  ),
                  color: AppColors.secondary,
                  icon: Icons.pending_actions_outlined,
                  onTap: () => _openResults(
                    chipFilters: const ManagementFilters(
                      paymentFilter: 'pending_confirmation',
                    ),
                    title: l10n.managementReceivablePendingApproval,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ReceivableMetricChip extends StatelessWidget {
  const ReceivableMetricChip({
    super.key,
    required this.label,
    required this.hint,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
    this.amount,
  });

  final String label;
  final String hint;
  final String count;
  final String? amount;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(ui.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ui.radiusSm),
        child: SizedBox(
          width: 148,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 6),
                Text(
                  count,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                ),
                if (amount != null && amount!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    amount!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
