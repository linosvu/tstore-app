import 'package:tstore/models/sale_order.dart';

class PreparationImage {
  const PreparationImage({
    required this.url,
    this.note,
    this.createdAt,
    this.mediaType,
  });

  final String url;
  final String? note;
  final String? createdAt;
  final String? mediaType;

  factory PreparationImage.fromJson(Map<String, dynamic> json) {
    return PreparationImage(
      url: json['url'] as String? ?? '',
      note: json['note'] as String?,
      createdAt: json['createdAt'] as String?,
      mediaType: json['mediaType'] as String?,
    );
  }
}

class PreparationOrderLinePublic {
  const PreparationOrderLinePublic({
    required this.id,
    required this.saleOrderLineId,
    required this.productName,
    required this.quantity,
    required this.isChecked,
    this.saleOrderLine,
  });

  final String id;
  final String saleOrderLineId;
  final String productName;
  final int quantity;
  final bool isChecked;
  final SaleOrderLinePublic? saleOrderLine;

  factory PreparationOrderLinePublic.fromJson(Map<String, dynamic> json) {
    final raw = json['saleOrderLine'];
    return PreparationOrderLinePublic(
      id: json['id'] as String? ?? '',
      saleOrderLineId: json['saleOrderLineId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      isChecked: json['isChecked'] as bool? ?? false,
      saleOrderLine: raw is Map<String, dynamic>
          ? SaleOrderLinePublic.fromJson(raw)
          : null,
    );
  }
}

class PreparationOrderPublic {
  const PreparationOrderPublic({
    required this.id,
    required this.code,
    required this.saleOrderId,
    required this.status,
    required this.isPublicBoard,
    this.assignedUserId,
    this.assignedUser,
    this.notes,
    this.linkedDeliveryScheduledAt,
    required this.images,
    required this.lines,
    this.saleOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String code;
  final String saleOrderId;
  final String status;
  final bool isPublicBoard;
  final String? assignedUserId;
  final SaleOrderCreatorBrief? assignedUser;
  final String? notes;
  final String? linkedDeliveryScheduledAt;
  final List<PreparationImage> images;
  final List<PreparationOrderLinePublic> lines;
  final SaleOrderPublic? saleOrder;
  final String createdAt;
  final String updatedAt;

  factory PreparationOrderPublic.fromJson(Map<String, dynamic> json) {
    final imgs = json['images'];
    final linesRaw = json['lines'];
    final soRaw = json['saleOrder'];
    final assigneeRaw = json['assignedUser'];
    return PreparationOrderPublic(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      saleOrderId: json['saleOrderId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      isPublicBoard: json['isPublicBoard'] as bool? ?? false,
      assignedUserId: json['assignedUserId'] as String?,
      assignedUser: assigneeRaw is Map<String, dynamic>
          ? SaleOrderCreatorBrief.fromJson(assigneeRaw)
          : null,
      notes: json['notes'] as String?,
      linkedDeliveryScheduledAt: json['linkedDeliveryScheduledAt'] as String?,
      images: imgs is List
          ? imgs
              .map((e) => PreparationImage.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      lines: linesRaw is List
          ? linesRaw
              .map(
                (e) =>
                    PreparationOrderLinePublic.fromJson(e as Map<String, dynamic>),
              )
              .toList()
          : const [],
      saleOrder: soRaw is Map<String, dynamic>
          ? SaleOrderPublic.fromJson(soRaw)
          : null,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}
