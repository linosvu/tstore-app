import 'package:tstore/models/delivery.dart';
import 'package:tstore/models/preparation_order.dart';
import 'package:tstore/models/sale_order.dart';

/// Một dòng từ `GET /admin/sale-orders/fulfillment` (đơn đã có ít nhất phiếu chuẩn bị hoặc đơn giao).
class OrderFulfillmentItem {
  const OrderFulfillmentItem({
    required this.saleOrder,
    this.preparation,
    this.delivery,
  });

  final SaleOrderPublic saleOrder;
  final PreparationOrderPublic? preparation;
  final DeliveryPublic? delivery;

  factory OrderFulfillmentItem.fromJson(Map<String, dynamic> json) {
    final soRaw = json['saleOrder'];
    final prepRaw = json['preparation'];
    final delRaw = json['delivery'];
    return OrderFulfillmentItem(
      saleOrder: SaleOrderPublic.fromJson(soRaw as Map<String, dynamic>),
      preparation: prepRaw is Map<String, dynamic>
          ? PreparationOrderPublic.fromJson(prepRaw)
          : null,
      delivery: delRaw is Map<String, dynamic>
          ? DeliveryPublic.fromJson(delRaw)
          : null,
    );
  }
}

class OrderFulfillmentListResult {
  const OrderFulfillmentListResult({
    required this.items,
    required this.totalPages,
    required this.total,
  });

  final List<OrderFulfillmentItem> items;
  final int totalPages;
  final int total;

  factory OrderFulfillmentListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List
        ? raw
            .map((e) => OrderFulfillmentItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <OrderFulfillmentItem>[];
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final limit = (json['limit'] as num?)?.toInt() ?? 20;
    final pages = (json['totalPages'] as num?)?.toInt() ??
        ((total / limit).ceil().clamp(1, 9999));
    return OrderFulfillmentListResult(
      items: list,
      totalPages: pages,
      total: total,
    );
  }
}
