class CustomerAddress {
  const CustomerAddress({
    required this.houseNumber,
    required this.wardId,
    required this.provinceId,
  });

  final String houseNumber;
  final String wardId;
  final String provinceId;

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      houseNumber: (json['houseNumber'] as String?) ?? '',
      wardId: (json['wardId'] as String?) ?? 'A',
      provinceId: (json['provinceId'] as String?) ?? 'X',
    );
  }

  Map<String, dynamic> toJson() => {
        'houseNumber': houseNumber,
        'wardId': wardId,
        'provinceId': provinceId,
      };
}

class CustomerPublic {
  const CustomerPublic({
    required this.id,
    required this.name,
    this.phone,
    required this.addresses,
  });

  final String id;
  final String name;
  final String? phone;
  final List<CustomerAddress> addresses;

  factory CustomerPublic.fromJson(Map<String, dynamic> json) {
    final addr = json['addresses'];
    final list = addr is List
        ? addr
            .map((e) => CustomerAddress.fromJson(e as Map<String, dynamic>))
            .toList()
        : <CustomerAddress>[];
    return CustomerPublic(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      addresses: list,
    );
  }
}

/// Khách (kèm GET chi tiết đơn khi backend join `customer`).
class SaleOrderCreatorBrief {
  const SaleOrderCreatorBrief({required this.id, required this.name});

  final String id;
  final String name;

  factory SaleOrderCreatorBrief.fromJson(Map<String, dynamic> json) {
    return SaleOrderCreatorBrief(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class SaleOrderCustomerBrief {
  const SaleOrderCustomerBrief({
    required this.id,
    required this.name,
    this.phone,
  });

  final String id;
  final String name;
  final String? phone;

  factory SaleOrderCustomerBrief.fromJson(Map<String, dynamic> json) {
    return SaleOrderCustomerBrief(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
    );
  }
}

class SaleOrderLinePublic {
  const SaleOrderLinePublic({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.fragile,
    required this.bulky,
    required this.needsInstallation,
    required this.carefulPackaging,
    required this.alreadyPaid,
    this.productCode,
    this.productName,
  });

  final String id;
  final String productId;
  final int quantity;
  final int unitPrice;
  final bool fragile;
  final bool bulky;
  final bool needsInstallation;
  final bool carefulPackaging;
  final bool alreadyPaid;
  final String? productCode;
  final String? productName;

  factory SaleOrderLinePublic.fromJson(Map<String, dynamic> json) {
    final p = json['product'] as Map<String, dynamic>?;
    return SaleOrderLinePublic(
      id: json['id'] as String,
      productId: json['productId'] as String,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toInt() ?? 0,
      fragile: json['fragile'] as bool? ?? false,
      bulky: json['bulky'] as bool? ?? false,
      needsInstallation: json['needsInstallation'] as bool? ?? false,
      carefulPackaging: json['carefulPackaging'] as bool? ?? false,
      alreadyPaid: json['alreadyPaid'] as bool? ?? false,
      productCode: p?['code'] as String?,
      productName: p?['name'] as String?,
    );
  }
}

class SaleOrderPaymentPublic {
  const SaleOrderPaymentPublic({
    required this.id,
    this.kiotVietPaymentId,
    this.code,
    this.method,
    required this.amount,
    this.statusValue,
    this.statusLabel,
    this.transDate,
    this.bankAccount,
    this.description,
    this.transferProofUrl,
    this.isScheduleReminder = false,
    this.recordStatus,
    this.requestedBy,
    this.confirmedBy,
    this.confirmedAt,
    this.scheduledPaymentDate,
  });

  final String id;
  final String? kiotVietPaymentId;
  final String? code;
  final String? method;
  final int amount;
  final int? statusValue;
  final String? statusLabel;
  final String? transDate;
  final String? bankAccount;
  final String? description;
  final String? transferProofUrl;
  final bool isScheduleReminder;

  /// `pending` | `confirmed` | null (đồng bộ KiotViet / cũ).
  final String? recordStatus;
  final SaleOrderCreatorBrief? requestedBy;
  final SaleOrderCreatorBrief? confirmedBy;
  final String? confirmedAt;
  final String? scheduledPaymentDate;

  factory SaleOrderPaymentPublic.fromJson(Map<String, dynamic> json) {
    final reqRaw = json['requestedBy'];
    final confRaw = json['confirmedBy'];
    return SaleOrderPaymentPublic(
      id: json['id'] as String,
      kiotVietPaymentId: json['kiotVietPaymentId'] as String?,
      code: json['code'] as String?,
      method: json['method'] as String?,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      statusValue: (json['statusValue'] as num?)?.toInt(),
      statusLabel: json['statusLabel'] as String?,
      transDate: json['transDate'] as String?,
      bankAccount: json['bankAccount'] as String?,
      description: json['description'] as String?,
      transferProofUrl: json['transferProofUrl'] as String?,
      isScheduleReminder: json['isScheduleReminder'] as bool? ?? false,
      recordStatus: json['recordStatus'] as String?,
      requestedBy: reqRaw is Map<String, dynamic>
          ? SaleOrderCreatorBrief.fromJson(reqRaw)
          : null,
      confirmedBy: confRaw is Map<String, dynamic>
          ? SaleOrderCreatorBrief.fromJson(confRaw)
          : null,
      confirmedAt: json['confirmedAt'] as String?,
      scheduledPaymentDate: json['scheduledPaymentDate'] as String?,
    );
  }
}

class SaleOrderPublic {
  const SaleOrderPublic({
    required this.id,
    required this.createdByUserId,
    this.orderSource = 'internal',
    this.kiotVietOrderCode,
    this.kiotVietPurchaseDate,
    this.customerId,
    this.customer,
    required this.status,
    required this.deliveryAddressSnapshot,
    this.deliveryGroupLabel,
    required this.paymentTerms,
    this.scheduledPaymentDate,
    required this.prepaidAmount,
    required this.subtotal,
    required this.linesPrepaidTotal,
    required this.amountDue,
    this.linkedPreparationStatus,
    this.linkedDeliveryStatus,
    this.notes,
    this.expectedDeliveryAt,
    this.createdBy,
    this.updatedByUserId,
    this.updatedBy,
    this.managedByUserId,
    this.managedBy,
    this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.lines,
    this.payments = const [],
  });

  final String id;
  final String createdByUserId;
  /// `internal` | `kiotviet`
  final String orderSource;
  final String? kiotVietOrderCode;
  /// ISO datetime từ KiotViet `purchaseDate` (nếu có).
  final String? kiotVietPurchaseDate;
  final String? customerId;
  final SaleOrderCustomerBrief? customer;
  final String status;
  final Map<String, dynamic> deliveryAddressSnapshot;
  final String? deliveryGroupLabel;
  final String paymentTerms;
  final String? scheduledPaymentDate;
  final int prepaidAmount;
  final int subtotal;
  final int linesPrepaidTotal;
  final int amountDue;
  /// Trạng thái chuẩn bị mới nhất (chỉ có ở API danh sách đơn bán).
  final String? linkedPreparationStatus;
  /// Trạng thái đơn giao mới nhất (chỉ có ở API danh sách đơn bán).
  final String? linkedDeliveryStatus;
  final String? notes;
  /// ISO 8601 — thời gian dự kiến giao hàng (đơn bán).
  final String? expectedDeliveryAt;
  final SaleOrderCreatorBrief? createdBy;
  final String? updatedByUserId;
  final SaleOrderCreatorBrief? updatedBy;
  final String? managedByUserId;
  final SaleOrderCreatorBrief? managedBy;
  final String? confirmedAt;
  final String createdAt;
  final String updatedAt;
  final List<SaleOrderLinePublic> lines;

  /// Chi tiết các lần thanh toán từ KiotViet.
  final List<SaleOrderPaymentPublic> payments;

  /// Đơn từ KiotViet (theo nguồn hoặc có mã / ngày mua KiotViet).
  bool get isKiotVietOrder =>
      orderSource == 'kiotviet' ||
      (kiotVietOrderCode?.trim().isNotEmpty ?? false) ||
      (kiotVietPurchaseDate?.trim().isNotEmpty ?? false);

  /// Mã hiển thị: ưu tiên [kiotVietOrderCode], ngược lại 8 ký tự đầu UUID.
  String get displayCode {
    final kv = kiotVietOrderCode?.trim();
    if (kv != null && kv.isNotEmpty) return kv;
    return id.substring(0, 8);
  }

  /// Đồng bộ với bước thanh toán trên thanh tiến độ đơn: đã xong khi đơn
  /// `completed` hoặc không còn nợ; không tính cho đơn hủy/hoàn.
  bool get isPaymentStepDone {
    if (status == 'cancelled' || status == 'refund') return false;
    if (status == 'completed') return true;
    return amountDue <= 0;
  }

  bool get hasPendingPaymentToConfirm =>
      payments.any(
        (p) => p.recordStatus == 'pending' && !p.isScheduleReminder,
      );

  bool get isPaymentCollectedForFinish =>
      isPaymentStepDone && !hasPendingPaymentToConfirm;

  bool isPrepReadyForFinish({String? linkedPrepStatus}) {
    final s = (linkedPrepStatus ?? linkedPreparationStatus)?.trim();
    if (s == null || s.isEmpty) return true;
    if (s == 'cancelled') return false;
    return s == 'ready' || s == 'done';
  }

  /// Có phiếu giao thì phải `completed` hoặc `cancelled` mới được kết thúc đơn.
  bool isDeliveryDoneForFinish({String? linkedDeliveryStatus}) {
    final s = (linkedDeliveryStatus ?? this.linkedDeliveryStatus)?.trim();
    if (s == null || s.isEmpty) return true;
    return s == 'completed' || s == 'cancelled';
  }

  bool canMarkOperationallyComplete({
    String? linkedPrepStatus,
    String? linkedDeliveryStatus,
  }) =>
      isPaymentCollectedForFinish &&
      isPrepReadyForFinish(linkedPrepStatus: linkedPrepStatus) &&
      isDeliveryDoneForFinish(linkedDeliveryStatus: linkedDeliveryStatus);

  bool get isOnManagementBoard =>
      isKiotVietOrder &&
      (managedByUserId == null || managedByUserId!.isEmpty);

  factory SaleOrderPublic.fromJson(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    final lines = linesRaw is List
        ? linesRaw
            .map((e) => SaleOrderLinePublic.fromJson(e as Map<String, dynamic>))
            .toList()
        : <SaleOrderLinePublic>[];
    final custRaw = json['customer'];
    final byRaw = json['createdBy'];
    final updatedByRaw = json['updatedBy'];
    return SaleOrderPublic(
      id: json['id'] as String,
      createdByUserId: json['createdByUserId'] as String? ?? '',
      orderSource: (json['orderSource'] as String?) ?? 'internal',
      kiotVietOrderCode: _jsonOptionalString(json['kiotVietOrderCode']),
      kiotVietPurchaseDate: _jsonOptionalString(json['kiotVietPurchaseDate']),
      customerId: json['customerId'] as String?,
      customer: custRaw is Map<String, dynamic>
          ? SaleOrderCustomerBrief.fromJson(custRaw)
          : null,
      status: json['status'] as String,
      deliveryAddressSnapshot: Map<String, dynamic>.from(
        (json['deliveryAddressSnapshot'] as Map?) ?? const {},
      ),
      deliveryGroupLabel: json['deliveryGroupLabel'] as String?,
      paymentTerms: json['paymentTerms'] as String? ?? 'pay_on_delivery',
      scheduledPaymentDate: json['scheduledPaymentDate'] as String?,
      prepaidAmount: (json['prepaidAmount'] as num?)?.toInt() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toInt() ?? 0,
      linesPrepaidTotal: (json['linesPrepaidTotal'] as num?)?.toInt() ?? 0,
      amountDue: (json['amountDue'] as num?)?.toInt() ?? 0,
      linkedPreparationStatus: json['linkedPreparationStatus'] as String?,
      linkedDeliveryStatus: json['linkedDeliveryStatus'] as String?,
      notes: json['notes'] as String?,
      expectedDeliveryAt: json['expectedDeliveryAt'] as String?,
      createdBy: byRaw is Map<String, dynamic>
          ? SaleOrderCreatorBrief.fromJson(byRaw)
          : null,
      updatedByUserId: json['updatedByUserId'] as String?,
      updatedBy: updatedByRaw is Map<String, dynamic>
          ? SaleOrderCreatorBrief.fromJson(updatedByRaw)
          : null,
      managedByUserId: json['managedByUserId'] as String?,
      managedBy: json['managedBy'] is Map<String, dynamic>
          ? SaleOrderCreatorBrief.fromJson(
              json['managedBy'] as Map<String, dynamic>,
            )
          : null,
      confirmedAt: json['confirmedAt'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      lines: lines,
      payments: (() {
        final raw = json['payments'];
        if (raw is List) {
          return raw
              .map((e) => SaleOrderPaymentPublic.fromJson(
                    e as Map<String, dynamic>,
                  ))
              .toList();
        }
        return <SaleOrderPaymentPublic>[];
      })(),
    );
  }
}

String? _jsonOptionalString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

/// Mã đơn dùng cho link / copy (thống nhất mọi màn).
String resolveSaleOrderDisplayCode({
  required String saleOrderId,
  SaleOrderPublic? saleOrder,
}) =>
    saleOrder?.displayCode ?? saleOrderId.substring(0, 8);

/// Cần GET `/admin/sale-orders/:id` vì nested `saleOrder` thiếu mã KiotViet.
bool saleOrderDisplayNeedsEnrich(SaleOrderPublic? saleOrder) {
  if (saleOrder == null) return true;
  if (!saleOrder.isKiotVietOrder) return false;
  final kv = saleOrder.kiotVietOrderCode?.trim();
  return kv == null || kv.isEmpty;
}
