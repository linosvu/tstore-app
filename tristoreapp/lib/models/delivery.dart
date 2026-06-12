import 'package:tstore/models/sale_order.dart';

/// Ảnh phiếu chuẩn bị gắn với đơn giao (phiếu CB mới nhất của đơn bán).
class LinkedPreparationBrief {
  const LinkedPreparationBrief({
    required this.id,
    required this.images,
  });

  final String id;
  final List<LinkedPreparationImage> images;

  factory LinkedPreparationBrief.fromJson(Map<String, dynamic> json) {
    final imgs = json['images'];
    return LinkedPreparationBrief(
      id: json['id'] as String? ?? '',
      images: imgs is List
          ? imgs
              .map(
                (e) => LinkedPreparationImage.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList()
          : const [],
    );
  }
}

class LinkedPreparationImage {
  const LinkedPreparationImage({
    required this.url,
    this.note,
    this.createdAt,
    this.mediaType,
  });

  final String url;
  final String? note;
  final String? createdAt;
  final String? mediaType;

  factory LinkedPreparationImage.fromJson(Map<String, dynamic> json) {
    return LinkedPreparationImage(
      url: json['url'] as String? ?? '',
      note: json['note'] as String?,
      createdAt: json['createdAt'] as String?,
      mediaType: json['mediaType'] as String?,
    );
  }
}

/// Ảnh check-in giao hàng (checkin / nhận hàng / lắp đặt).
class DeliveryCheckinImage {
  const DeliveryCheckinImage({
    required this.url,
    required this.type,
    this.note,
    this.mediaType,
  });

  final String url;
  final String type;
  final String? note;
  final String? mediaType;

  factory DeliveryCheckinImage.fromJson(Map<String, dynamic> json) {
    return DeliveryCheckinImage(
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? 'checkin',
      note: json['note'] as String?,
      mediaType: json['mediaType'] as String?,
    );
  }
}

class DeliveryUserBrief {
  const DeliveryUserBrief({required this.id, required this.name});

  final String id;
  final String name;

  factory DeliveryUserBrief.fromJson(Map<String, dynamic> json) {
    return DeliveryUserBrief(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class DeliveryLinePublic {
  const DeliveryLinePublic({
    required this.id,
    required this.saleOrderLineId,
    required this.quantityToDeliver,
    required this.isPrepared,
    required this.preparationChecklistState,
    this.saleOrderLine,
  });

  final String id;
  final String saleOrderLineId;
  final int quantityToDeliver;
  final bool isPrepared;
  /// Khóa = id checklist server; giá trị = đã tick.
  final Map<String, bool> preparationChecklistState;
  final SaleOrderLinePublic? saleOrderLine;

  static Map<String, bool> _parseChecklistState(dynamic raw) {
    if (raw is! Map) return {};
    final out = <String, bool>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (v is bool) {
        out[e.key.toString()] = v;
      }
    }
    return out;
  }

  factory DeliveryLinePublic.fromJson(Map<String, dynamic> json) {
    final sol = json['saleOrderLine'];
    return DeliveryLinePublic(
      id: json['id'] as String,
      saleOrderLineId: json['saleOrderLineId'] as String,
      quantityToDeliver: (json['quantityToDeliver'] as num?)?.toInt() ?? 0,
      isPrepared: json['isPrepared'] as bool? ?? false,
      preparationChecklistState: _parseChecklistState(
        json['preparationChecklistState'],
      ),
      saleOrderLine: sol is Map<String, dynamic>
          ? SaleOrderLinePublic.fromJson(sol)
          : null,
    );
  }
}

class DeliveryPublic {
  const DeliveryPublic({
    required this.id,
    this.deliveryCode,
    required this.saleOrderId,
    required this.createdByUserId,
    this.assignedUserId,
    required this.status,
    this.cancelReason,
    required this.paymentCollected,
    this.deliveryNote,
    this.scheduledAt,
    required this.priority,
    this.shippingCarrier,
    required this.isPublicBoard,
    required this.checkinImages,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.assignedUser,
    this.saleOrder,
    required this.lines,
    this.linkedPreparationStatus,
    this.linkedPreparation,
  });

  final String id;
  final String? deliveryCode;
  final String saleOrderId;
  final String createdByUserId;
  final String? assignedUserId;
  final String status;
  final String? cancelReason;
  final bool paymentCollected;
  final String? deliveryNote;
  final String? scheduledAt;
  final String priority;
  final String? shippingCarrier;
  final bool isPublicBoard;
  final List<DeliveryCheckinImage> checkinImages;
  final String? deliveredAt;
  final String createdAt;
  final String updatedAt;
  final DeliveryUserBrief? createdBy;
  final DeliveryUserBrief? assignedUser;
  final SaleOrderPublic? saleOrder;
  final List<DeliveryLinePublic> lines;
  /// Trạng thái phiếu chuẩn bị mới nhất của đơn bán liên quan (nếu có).
  /// Backend chỉ trả ở `/admin/deliveries` (list & one).
  final String? linkedPreparationStatus;
  /// Phiếu chuẩn bị mới nhất + ảnh (chi tiết đơn giao).
  final LinkedPreparationBrief? linkedPreparation;

  factory DeliveryPublic.fromJson(Map<String, dynamic> json) {
    final imgs = json['checkinImages'];
    final linesRaw = json['lines'];
    final so = json['saleOrder'];
    final cb = json['createdBy'];
    final au = json['assignedUser'];
    return DeliveryPublic(
      id: json['id'] as String,
      deliveryCode: json['deliveryCode'] as String?,
      saleOrderId: json['saleOrderId'] as String,
      createdByUserId: json['createdByUserId'] as String,
      assignedUserId: json['assignedUserId'] as String?,
      status: json['status'] as String? ?? 'pending',
      cancelReason: json['cancelReason'] as String?,
      paymentCollected: json['paymentCollected'] as bool? ?? false,
      deliveryNote: json['deliveryNote'] as String?,
      scheduledAt: json['scheduledAt'] as String?,
      priority: json['priority'] as String? ?? 'normal',
      shippingCarrier: json['shippingCarrier'] as String?,
      isPublicBoard: json['isPublicBoard'] as bool? ?? false,
      checkinImages: imgs is List
          ? imgs
              .map(
                (e) => DeliveryCheckinImage.fromJson(e as Map<String, dynamic>),
              )
              .toList()
          : const [],
      deliveredAt: json['deliveredAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      createdBy: cb is Map<String, dynamic>
          ? DeliveryUserBrief.fromJson(cb)
          : null,
      assignedUser: au is Map<String, dynamic>
          ? DeliveryUserBrief.fromJson(au)
          : null,
      saleOrder: so is Map<String, dynamic>
          ? SaleOrderPublic.fromJson(so)
          : null,
      lines: linesRaw is List
          ? linesRaw
              .map((e) => DeliveryLinePublic.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      linkedPreparationStatus: json['linkedPreparationStatus'] as String?,
      linkedPreparation: json['linkedPreparation'] is Map<String, dynamic>
          ? LinkedPreparationBrief.fromJson(
              json['linkedPreparation'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
