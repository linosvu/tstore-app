import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/models/delivery.dart';
import 'package:tstore/providers/address_catalog_provider.dart';
import 'package:tstore/screens/delivery/delivery_ui.dart';
import 'package:tstore/screens/preparation/preparation_ui.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

class DeliveryCompactCard extends StatelessWidget {
  const DeliveryCompactCard({
    super.key,
    required this.d,
    required this.l10n,
    required this.scheme,
    required this.onOpenDetail,
    this.onAssignMe,
    this.onEdit,
    this.showPriorityBeforeStatus = false,
  });

  final DeliveryPublic d;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final VoidCallback onOpenDetail;
  final VoidCallback? onAssignMe;
  final VoidCallback? onEdit;
  /// Tab Đơn của tôi: hiển thị độ ưu tiên (text thường) rồi trạng thái có màu.
  final bool showPriorityBeforeStatus;

  @override
  Widget build(BuildContext context) {
    final so = d.saleOrder;
    final cust = so?.customer;
    final name = cust?.name ?? '—';
    final phone = cust?.phone?.trim();
    final phoneLine = (phone != null && phone.isNotEmpty) ? phone : '—';
    final addr =
        deliveryAddressLine(d, context.watch<AddressCatalogProvider>());
    final due = so?.amountDue ?? 0;

    return AppSurfaceCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.space2),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpenDetail,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '#${d.saleOrderId.substring(0, 8)}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Flexible(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              if (showPriorityBeforeStatus) ...[
                                TextSpan(
                                  text: deliveryPriorityLabel(d.priority, l10n),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                TextSpan(
                                  text: ' · ',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                              TextSpan(
                                text: deliveryStatusLabel(d.status, l10n),
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: deliveryStatusColor(
                                        d.status,
                                        Theme.of(context),
                                      ),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (d.deliveryCode != null &&
                          d.deliveryCode!.trim().isNotEmpty)
                        Expanded(
                          child: Text(
                            '${l10n.deliveryDeliveryCode}: ${d.deliveryCode}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (d.deliveryCode != null &&
                          d.deliveryCode!.trim().isNotEmpty)
                        const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9C4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            '${l10n.deliveryAmountDueLabel}: ${deliveryFormatMoney(due)}',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  Text(
                    '$name · $phoneLine',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    addr.isEmpty ? '—' : addr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  if (d.scheduledAt != null && d.scheduledAt!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.space2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n.deliveryScheduled}: ${deliveryScheduledFormatted(d.scheduledAt) ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DeliveryCountdownTicker(
                          scheduledAtIso: d.scheduledAt,
                          l10n: l10n,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.tertiary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ],
                  if (d.linkedPreparationStatus != null &&
                      d.linkedPreparationStatus!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.space2),
                    StatusBadge(
                      label:
                          '${l10n.prepNav}: ${preparationStatusLabel(d.linkedPreparationStatus!, l10n)}',
                      expand: true,
                      tone: preparationStatusTone(
                        d.linkedPreparationStatus!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onAssignMe != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space3,
                0,
                AppSpacing.space3,
                AppSpacing.space3,
              ),
              child: FilledButton.tonalIcon(
                onPressed: onAssignMe,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l10n.deliveryAssignMe),
              ),
            ),
          if (onEdit != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space3,
                0,
                AppSpacing.space3,
                AppSpacing.space3,
              ),
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.edit),
              ),
            ),
        ],
      ),
    );
  }
}
