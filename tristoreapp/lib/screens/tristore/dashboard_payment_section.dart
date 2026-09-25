import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/utils/amount_input.dart';
import 'package:tstore/models/dashboard_payment_record.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/screens/orders/sale_order_detail_screen.dart';
import 'package:tstore/screens/service_request/onsite_ticket_screen.dart';
import 'package:tstore/screens/service_request/repair_ticket_screen.dart';
import 'package:tstore/screens/tristore/payment_records_list_screen.dart';
import 'package:tstore/widgets/ui/app_surface_card.dart';

Future<DashboardPaymentRecordsPage?> fetchDashboardPaymentRecords(
  AuthProvider auth, {
  int page = 1,
  int limit = 20,
}) async {
  try {
    final res = await auth.api.get<Map<String, dynamic>>(
      '/admin/dashboard/payment-records',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = res.data;
    if (data == null) return null;
    return DashboardPaymentRecordsPage.fromJson(data);
  } on DioException {
    return null;
  }
}

void openPaymentRecordParent(
  BuildContext context,
  DashboardPaymentRecord item,
) {
  switch (item.source) {
    case 'onsite':
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OnsiteTicketScreen(ticketId: item.parentId),
        ),
      );
    case 'repair':
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => RepairTicketScreen(ticketId: item.parentId),
        ),
      );
    default:
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SaleOrderDetailScreen(orderId: item.parentId),
        ),
      );
  }
}

String formatPaymentRecordWhen(DateTime dt) {
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// Section «Thanh toán» trên trang chủ (tối đa 5 dòng).
class DashboardPaymentSection extends StatelessWidget {
  const DashboardPaymentSection({
    super.key,
    required this.page,
    required this.loading,
    required this.showManager,
  });

  final DashboardPaymentRecordsPage? page;
  final bool loading;
  final bool showManager;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = page?.items ?? const <DashboardPaymentRecord>[];
    final total = page?.total ?? 0;
    final todayPending = page?.todayPendingCount ?? 0;

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thanh toán',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                'hôm nay: $todayPending',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.space2),
          if (loading && page == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Không có ghi nhận thanh toán.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
            )
          else
            ...items.map(
              (e) => DashboardPaymentRecordTile(
                item: e,
                showManager: showManager,
                onTap: () => openPaymentRecordParent(context, e),
              ),
            ),
          if (total > 5) ...[
            const SizedBox(height: AppSpacing.space1),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PaymentRecordsListScreen(),
                    ),
                  );
                },
                child: const Text('Xem thêm'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardPaymentRecordTile extends StatelessWidget {
  const DashboardPaymentRecordTile({
    super.key,
    required this.item,
    required this.showManager,
    this.onTap,
    this.dense = true,
  });

  final DashboardPaymentRecord item;
  final bool showManager;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amountText =
        '${formatIntegerWithSeparator(item.amount, ThousandsGroupSeparatorKey.dot)} đ';
    final dueText =
        '${formatIntegerWithSeparator(item.parentAmountDue, ThousandsGroupSeparatorKey.dot)} đ';
    final titleParts = <String>[
      item.parentCode,
      if (showManager && (item.managerName ?? '').trim().isNotEmpty)
        item.managerName!.trim(),
    ];
    final subtitleParts = <String>[
      item.recordStatusLabelVi,
      formatPaymentRecordWhen(item.createdAt),
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 8 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.source == 'repair'
                  ? Icons.build_outlined
                  : item.source == 'onsite'
                      ? Icons.home_repair_service_outlined
                      : Icons.receipt_long_outlined,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleParts.join(' · '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleParts.join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dueText,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
