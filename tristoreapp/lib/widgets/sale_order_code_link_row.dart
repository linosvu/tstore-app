import 'package:flutter/material.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/screens/orders/sale_order_detail_screen.dart';

/// Dòng mã đơn bán: nhãn + mã in đậm (bấm mở chi tiết) + nút copy tùy chọn.
class SaleOrderCodeLinkRow extends StatelessWidget {
  const SaleOrderCodeLinkRow({
    super.key,
    required this.saleOrderId,
    required this.displayCode,
    this.labelPrefix,
    this.onCopy,
    this.copyTooltip,
  });

  final String saleOrderId;
  final String displayCode;
  final String? labelPrefix;
  final VoidCallback? onCopy;
  final String? copyTooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final prefix = labelPrefix ?? '${l10n.ordersOrderShort}:';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                prefix,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              InkWell(
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => SaleOrderDetailScreen(orderId: saleOrderId),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Text(
                    '#$displayCode',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            tooltip: copyTooltip ?? l10n.copyText,
            visualDensity: VisualDensity.compact,
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
      ],
    );
  }
}
