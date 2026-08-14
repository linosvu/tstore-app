/// Phiếu yêu cầu / phiếu con từ `/admin/service-requests` & `/admin/service-tickets`.
library;

import 'dart:convert';

/// 23:59:59.999 ngày mai (giờ máy).
DateTime endOfTomorrowLocal() {
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day)
      .add(const Duration(days: 1));
  return DateTime(
    tomorrow.year,
    tomorrow.month,
    tomorrow.day,
    23,
    59,
    59,
    999,
  );
}

class ServiceAttachment {
  const ServiceAttachment({
    required this.url,
    this.mediaType,
    this.createdAt,
  });

  final String url;
  final String? mediaType;
  final String? createdAt;

  factory ServiceAttachment.fromJson(Map<String, dynamic> json) {
    return ServiceAttachment(
      url: json['url'] as String? ?? '',
      mediaType: json['mediaType'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        if (mediaType != null) 'mediaType': mediaType,
      };
}

class ServiceTicketBrief {
  const ServiceTicketBrief({
    required this.id,
    this.code,
    required this.type,
    required this.status,
    required this.staffUserId,
    this.staffName,
    this.receiveStaffName,
    this.deliveryStaffName,
    this.repairStartedAt,
    this.contactDeadlineAt,
    this.etaDate,
    this.deliveryEta,
    this.feeAmount = 0,
    this.isFree = true,
    this.costMode,
    this.paymentMethod,
    this.paymentAmount,
    this.partCost,
    this.laborCost,
    this.outstandingDue,
    this.hasConfirmedCollectingPayment = false,
    this.appointmentDate,
    this.appointmentSlot,
    this.deadlineAt,
    this.contactFailedCount = 0,
    this.isOverdue = false,
    this.statusChangedAt,
    this.createdAt,
  });

  final String id;
  final String? code;
  final String type;
  final String status;
  final String staffUserId;
  final String? staffName;
  final String? receiveStaffName;
  final String? deliveryStaffName;
  final String? repairStartedAt;
  final String? contactDeadlineAt;
  /// YYYY-MM-DD — ETA hoàn thành sửa (bước Sửa chữa).
  final String? etaDate;
  /// ISO — hẹn giao khi bàn giao tận nhà.
  final String? deliveryEta;
  final int feeAmount;
  final bool isFree;
  /// `free` | `paid` | null (chưa chọn trên phiếu HTN).
  final String? costMode;
  final String? paymentMethod;
  final int? paymentAmount;
  final int? partCost;
  final int? laborCost;
  final int? outstandingDue;
  final bool hasConfirmedCollectingPayment;
  final String? appointmentDate;
  final String? appointmentSlot;
  final String? deadlineAt;
  final int contactFailedCount;
  final bool isOverdue;
  final String? statusChangedAt;
  final String? createdAt;

  String get displayCode =>
      code ?? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id);

  /// `free` | `paid` — ưu tiên costMode; fallback isFree.
  String get costDisplayMode {
    final mode = costMode ?? (isFree ? 'free' : 'paid');
    return mode;
  }

  /// Số tiền hiển thị list: SC ưu tiên paymentAmount → part+labor → feeAmount.
  int get listMoneyAmount {
    if (type == 'repair') {
      if (paymentAmount != null) return paymentAmount!;
      final parts = (partCost ?? 0) + (laborCost ?? 0);
      if (parts > 0) return parts;
    }
    return feeAmount;
  }

  bool get listMoneyIsFree {
    if (type == 'repair') {
      final method = (paymentMethod ?? '').trim();
      if (method == 'free') return true;
      if (paymentAmount != null) return paymentAmount == 0 && method == 'free';
    }
    return feeAmount <= 0;
  }

  /// Hạn liên quan cần xử lý (deadline / hẹn gọi / ETA / hẹn giao).
  DateTime? get dueHandleAt {
    DateTime? best;
    void consider(DateTime? dt) {
      if (dt == null) return;
      if (best == null || dt.isBefore(best!)) best = dt;
    }

    consider(DateTime.tryParse(deadlineAt ?? ''));
    consider(DateTime.tryParse(contactDeadlineAt ?? ''));
    consider(DateTime.tryParse(deliveryEta ?? ''));
    final eta = (etaDate ?? '').trim();
    if (eta.isNotEmpty) {
      consider(
        DateTime.tryParse(eta.length == 10 ? '${eta}T23:59:59' : eta),
      );
    }
    return best?.toLocal();
  }

  /// Có hạn xử lý ≤ 23:59 ngày mai (kèm quá hạn).
  bool get isDueSoon {
    if (isTicketClosedStatus) return false;
    final due = dueHandleAt;
    if (due == null) return false;
    return !due.isAfter(endOfTomorrowLocal());
  }

  bool get isTicketClosedStatus {
    switch (type) {
      case 'online':
      case 'other':
        return status == 'done' ||
            status == 'failed' ||
            status == 'cancelled';
      case 'onsite':
        return status == 'done' ||
            status == 'failed' ||
            status == 'taken' ||
            status == 'cancelled';
      default:
        return status == 'completed' ||
            status == 'customer_rejected' ||
            status == 'cancelled';
    }
  }

  factory ServiceTicketBrief.fromJson(Map<String, dynamic> json) {
    return ServiceTicketBrief(
      id: json['id'] as String,
      code: json['code'] as String?,
      type: json['type'] as String? ?? 'online',
      status: json['status'] as String? ?? 'processing',
      staffUserId: json['staffUserId'] as String? ?? '',
      staffName: json['staffName'] as String?,
      receiveStaffName: json['receiveStaffName'] as String?,
      deliveryStaffName: json['deliveryStaffName'] as String?,
      repairStartedAt: json['repairStartedAt'] as String?,
      contactDeadlineAt: json['contactDeadlineAt'] as String?,
      etaDate: json['etaDate'] as String?,
      deliveryEta: json['deliveryEta'] as String?,
      feeAmount: (json['feeAmount'] as num?)?.toInt() ?? 0,
      isFree: json['isFree'] as bool? ?? true,
      costMode: json['costMode'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      paymentAmount: (json['paymentAmount'] as num?)?.toInt(),
      partCost: (json['partCost'] as num?)?.toInt(),
      laborCost: (json['laborCost'] as num?)?.toInt(),
      outstandingDue: (json['outstandingDue'] as num?)?.toInt(),
      hasConfirmedCollectingPayment:
          json['hasConfirmedCollectingPayment'] as bool? ?? false,
      appointmentDate: json['appointmentDate'] as String?,
      appointmentSlot: json['appointmentSlot'] as String?,
      deadlineAt: json['deadlineAt'] as String?,
      contactFailedCount: (json['contactFailedCount'] as num?)?.toInt() ?? 0,
      isOverdue: json['isOverdue'] as bool? ?? false,
      statusChangedAt: json['statusChangedAt'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class ServiceRequestPublic {
  const ServiceRequestPublic({
    required this.id,
    this.code,
    this.direction = 'support',
    required this.channel,
    required this.customerName,
    required this.customerPhone,
    this.customerPhone2,
    this.customerAddress,
    this.customerNote,
    this.buyerName,
    this.buyerPhone,
    this.buyerAddress,
    required this.productName,
    this.productSerial,
    required this.issueDescription,
    this.attachments = const [],
    this.managerUserId,
    this.managerName,
    this.supportStaffUserId,
    this.supportStaffName,
    required this.status,
    this.cancelReason,
    required this.createdByUserId,
    this.createdByName,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
    this.tickets = const [],
    this.canComplete = false,
  });

  final String id;
  final String? code;
  /** `support` | `repair` */
  final String direction;
  final String channel;
  final String customerName;
  final String customerPhone;
  final String? customerPhone2;
  final String? customerAddress;
  final String? customerNote;
  final String? buyerName;
  final String? buyerPhone;
  final String? buyerAddress;
  final String productName;
  final String? productSerial;
  final String issueDescription;
  final List<ServiceAttachment> attachments;
  final String? managerUserId;
  final String? managerName;
  final String? supportStaffUserId;
  final String? supportStaffName;
  final String status;
  final String? cancelReason;
  final String createdByUserId;
  final String? createdByName;
  final String? closedAt;
  final String? createdAt;
  final String? updatedAt;
  final List<ServiceTicketBrief> tickets;
  final bool canComplete;

  String get displayCode =>
      code ?? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id);

  ServiceTicketBrief? get latestTicket =>
      tickets.isEmpty ? null : tickets.last;

  bool get hasOverdueTicket => tickets.any((t) => t.isOverdue);

  bool get hasDueSoonTicket => tickets.any((t) => t.isDueSoon);

  bool get isRepairDirection => direction == 'repair';

  factory ServiceRequestPublic.fromJson(Map<String, dynamic> json) {
    final attRaw = json['attachments'];
    final ticketsRaw = json['tickets'];
    return ServiceRequestPublic(
      id: json['id'] as String,
      code: json['code'] as String?,
      direction: json['direction'] as String? ?? 'support',
      channel: json['channel'] as String? ?? 'other',
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      customerPhone2: json['customerPhone2'] as String?,
      customerAddress: json['customerAddress'] as String?,
      customerNote: json['customerNote'] as String?,
      buyerName: json['buyerName'] as String?,
      buyerPhone: json['buyerPhone'] as String?,
      buyerAddress: json['buyerAddress'] as String?,
      productName: json['productName'] as String? ?? '',
      productSerial: json['productSerial'] as String?,
      issueDescription: json['issueDescription'] as String? ?? '',
      attachments: attRaw is List
          ? [
              for (final e in attRaw)
                if (e is Map<String, dynamic>) ServiceAttachment.fromJson(e),
            ]
          : const [],
      managerUserId: json['managerUserId'] as String?,
      managerName: json['managerName'] as String?,
      supportStaffUserId: json['supportStaffUserId'] as String?,
      supportStaffName: json['supportStaffName'] as String?,
      status: json['status'] as String? ?? 'new',
      cancelReason: json['cancelReason'] as String?,
      createdByUserId: json['createdByUserId'] as String? ?? '',
      createdByName: json['createdByName'] as String?,
      closedAt: json['closedAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      tickets: ticketsRaw is List
          ? [
              for (final e in ticketsRaw)
                if (e is Map<String, dynamic>) ServiceTicketBrief.fromJson(e),
            ]
          : const [],
      canComplete: json['canComplete'] as bool? ?? false,
    );
  }
}

class ServiceRequestBrief {
  const ServiceRequestBrief({
    required this.id,
    this.code,
    required this.channel,
    required this.customerName,
    required this.customerPhone,
    this.customerPhone2,
    this.customerAddress,
    this.customerNote,
    this.buyerName,
    this.buyerPhone,
    this.buyerAddress,
    required this.productName,
    this.productSerial,
    required this.issueDescription,
    this.attachments = const [],
    this.managerUserId,
    this.managerName,
    this.supportStaffUserId,
    this.supportStaffName,
    this.createdByUserId,
    this.createdByName,
    required this.status,
  });

  final String id;
  final String? code;
  final String channel;
  final String customerName;
  final String customerPhone;
  final String? customerPhone2;
  final String? customerAddress;
  final String? customerNote;
  final String? buyerName;
  final String? buyerPhone;
  final String? buyerAddress;
  final String productName;
  final String? productSerial;
  final String issueDescription;
  final List<ServiceAttachment> attachments;
  final String? managerUserId;
  final String? managerName;
  final String? supportStaffUserId;
  final String? supportStaffName;
  final String? createdByUserId;
  final String? createdByName;
  final String status;

  factory ServiceRequestBrief.fromJson(Map<String, dynamic> json) {
    final attRaw = json['attachments'];
    return ServiceRequestBrief(
      id: json['id'] as String,
      code: json['code'] as String?,
      channel: json['channel'] as String? ?? 'other',
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      customerPhone2: json['customerPhone2'] as String?,
      customerAddress: json['customerAddress'] as String?,
      customerNote: json['customerNote'] as String?,
      buyerName: json['buyerName'] as String?,
      buyerPhone: json['buyerPhone'] as String?,
      buyerAddress: json['buyerAddress'] as String?,
      productName: json['productName'] as String? ?? '',
      productSerial: json['productSerial'] as String?,
      issueDescription: json['issueDescription'] as String? ?? '',
      attachments: attRaw is List
          ? [
              for (final e in attRaw)
                if (e is Map<String, dynamic>) ServiceAttachment.fromJson(e),
            ]
          : const [],
      managerUserId: json['managerUserId'] as String?,
      managerName: json['managerName'] as String?,
      supportStaffUserId: json['supportStaffUserId'] as String?,
      supportStaffName: json['supportStaffName'] as String?,
      createdByUserId: json['createdByUserId'] as String?,
      createdByName: json['createdByName'] as String?,
      status: json['status'] as String? ?? 'new',
    );
  }
}

class RepairDetailPublic {
  const RepairDetailPublic({
    required this.ticketId,
    this.receiveType,
    this.receiveStaffUserId,
    this.receiveStaffName,
    this.initialAssessment,
    this.extraNote,
    this.repairMethod,
    this.solution,
    this.partCost,
    this.laborCost,
    this.etaDate,
    this.contactConfirmedAt,
    this.contactDeadlineAt,
    this.contactNote,
    this.rejectCountInspect = 0,
    this.rejectCountResult = 0,
    this.approvedInspectAt,
    this.approvedInspectBy,
    this.repairResult,
    this.warrantyMonths,
    this.receiveBackNote,
    this.repairContactNote,
    this.deliveryStaffUserId,
    this.deliveryStaffName,
    this.abortReason,
    this.abortedAt,
    this.repairStartedAt,
    this.deliveryMethod,
    this.deliveryEta,
    this.shippingFeePayer,
    this.paymentAmount,
    this.paymentMethod,
    this.paymentDueDate,
    this.paymentNote,
    this.paymentProofUrls = const [],
    this.paymentSubmittedAt,
    this.paymentConfirmedAt,
    this.paymentConfirmedBy,
    this.customerRejectPending = false,
  });

  final String ticketId;
  final String? receiveType;
  final String? receiveStaffUserId;
  final String? receiveStaffName;
  final String? initialAssessment;
  final String? extraNote;
  final String? repairMethod;
  final String? solution;
  final int? partCost;
  final int? laborCost;
  final String? etaDate;
  final String? contactConfirmedAt;
  final String? contactDeadlineAt;
  final String? contactNote;
  final int rejectCountInspect;
  final int rejectCountResult;
  final String? approvedInspectAt;
  final String? approvedInspectBy;
  final String? repairResult;
  final int? warrantyMonths;
  final String? receiveBackNote;
  final String? repairContactNote;
  final String? deliveryStaffUserId;
  final String? deliveryStaffName;
  final String? abortReason;
  final String? abortedAt;
  final String? repairStartedAt;
  final String? deliveryMethod;
  final String? deliveryEta;
  final String? shippingFeePayer;
  final int? paymentAmount;
  final String? paymentMethod;
  final String? paymentDueDate;
  final String? paymentNote;
  final List<String> paymentProofUrls;
  final String? paymentSubmittedAt;
  final String? paymentConfirmedAt;
  final String? paymentConfirmedBy;
  final bool customerRejectPending;

  factory RepairDetailPublic.fromJson(Map<String, dynamic> json) {
    final proofs = json['paymentProofUrls'];
    return RepairDetailPublic(
      ticketId: json['ticketId'] as String? ?? '',
      receiveType: json['receiveType'] as String?,
      receiveStaffUserId: json['receiveStaffUserId'] as String?,
      receiveStaffName: json['receiveStaffName'] as String?,
      initialAssessment: json['initialAssessment'] as String?,
      extraNote: json['extraNote'] as String?,
      repairMethod: json['repairMethod'] as String?,
      solution: json['solution'] as String?,
      partCost: (json['partCost'] as num?)?.toInt(),
      laborCost: (json['laborCost'] as num?)?.toInt(),
      etaDate: json['etaDate'] as String?,
      contactConfirmedAt: json['contactConfirmedAt'] as String?,
      contactDeadlineAt: json['contactDeadlineAt'] as String?,
      contactNote: json['contactNote'] as String?,
      rejectCountInspect: (json['rejectCountInspect'] as num?)?.toInt() ?? 0,
      rejectCountResult: (json['rejectCountResult'] as num?)?.toInt() ?? 0,
      approvedInspectAt: json['approvedInspectAt'] as String?,
      approvedInspectBy: json['approvedInspectBy'] as String?,
      repairResult: json['repairResult'] as String?,
      warrantyMonths: (json['warrantyMonths'] as num?)?.toInt(),
      receiveBackNote: json['receiveBackNote'] as String?,
      repairContactNote: json['repairContactNote'] as String?,
      deliveryStaffUserId: json['deliveryStaffUserId'] as String?,
      deliveryStaffName: json['deliveryStaffName'] as String?,
      abortReason: json['abortReason'] as String?,
      abortedAt: json['abortedAt'] as String?,
      repairStartedAt: json['repairStartedAt'] as String?,
      deliveryMethod: json['deliveryMethod'] as String?,
      deliveryEta: json['deliveryEta'] as String?,
      shippingFeePayer: json['shippingFeePayer'] as String?,
      paymentAmount: (json['paymentAmount'] as num?)?.toInt(),
      paymentMethod: json['paymentMethod'] as String?,
      paymentDueDate: json['paymentDueDate'] as String?,
      paymentNote: json['paymentNote'] as String?,
      paymentProofUrls: proofs is List
          ? proofs.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      paymentSubmittedAt: json['paymentSubmittedAt'] as String?,
      paymentConfirmedAt: json['paymentConfirmedAt'] as String?,
      paymentConfirmedBy: json['paymentConfirmedBy'] as String?,
      customerRejectPending: json['customerRejectPending'] as bool? ?? false,
    );
  }
}


class TicketEvidencePublic {
  const TicketEvidencePublic({
    required this.id,
    this.ticketId,
    required this.stage,
    required this.kind,
    required this.fileUrl,
    this.createdByUserId,
    this.createdAt,
  });

  final String id;
  final String? ticketId;
  final String stage;
  final String kind;
  final String fileUrl;
  final String? createdByUserId;
  final String? createdAt;

  factory TicketEvidencePublic.fromJson(Map<String, dynamic> json) {
    return TicketEvidencePublic(
      id: json['id'] as String,
      ticketId: json['ticketId'] as String?,
      stage: json['stage'] as String? ?? '',
      kind: json['kind'] as String? ?? 'image',
      fileUrl: json['fileUrl'] as String? ?? '',
      createdByUserId: json['createdByUserId'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class TicketLogPublic {
  const TicketLogPublic({
    required this.id,
    required this.action,
    this.field,
    this.oldValue,
    this.newValue,
    this.reason,
    this.actorUserId,
    this.actorName,
    this.createdAt,
  });

  final String id;
  final String action;
  final String? field;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final String? actorUserId;
  final String? actorName;
  final String? createdAt;

  factory TicketLogPublic.fromJson(Map<String, dynamic> json) {
    return TicketLogPublic(
      id: json['id'] as String,
      action: json['action'] as String? ?? '',
      field: json['field'] as String?,
      oldValue: json['oldValue'] as String?,
      newValue: json['newValue'] as String?,
      reason: json['reason'] as String?,
      actorUserId: json['actorUserId'] as String?,
      actorName: json['actorName'] as String?,
      createdAt: json['createdAt'] as String?,
    );
  }
}

class TicketSignaturePublic {
  const TicketSignaturePublic({
    required this.id,
    this.ticketId,
    required this.stage,
    required this.signer,
    required this.imageUrl,
    this.signedAt,
  });

  final String id;
  final String? ticketId;
  final String stage;
  final String signer;
  final String imageUrl;
  final String? signedAt;

  factory TicketSignaturePublic.fromJson(Map<String, dynamic> json) {
    return TicketSignaturePublic(
      id: json['id'] as String,
      ticketId: json['ticketId'] as String?,
      stage: json['stage'] as String? ?? '',
      signer: json['signer'] as String? ?? 'staff',
      imageUrl: json['imageUrl'] as String? ?? '',
      signedAt: json['signedAt'] as String?,
    );
  }
}

class TicketCostItem {
  const TicketCostItem({required this.content, required this.amount});

  final String content;
  final int amount;

  factory TicketCostItem.fromJson(Map<String, dynamic> json) {
    return TicketCostItem(
      content: json['content'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'content': content, 'amount': amount};
}

class TicketUserBrief {
  const TicketUserBrief({required this.id, required this.name});

  final String id;
  final String name;

  factory TicketUserBrief.fromJson(Map<String, dynamic> json) {
    return TicketUserBrief(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class ServiceTicketPaymentPublic {
  const ServiceTicketPaymentPublic({
    required this.id,
    required this.method,
    this.methodLabel,
    required this.amount,
    this.statusLabel,
    this.transDate,
    this.description,
    this.transferProofUrl,
    List<String>? transferProofUrlsCached,
    this.recordStatus,
    this.requestedBy,
    this.confirmedBy,
    this.confirmedAt,
    this.scheduledPaymentDate,
  }) : _transferProofUrlsCached = transferProofUrlsCached;

  final String id;
  final String method;
  final String? methodLabel;
  final int amount;
  final String? statusLabel;
  final String? transDate;
  final String? description;
  final String? transferProofUrl;
  final String? recordStatus;
  final TicketUserBrief? requestedBy;
  final TicketUserBrief? confirmedBy;
  final String? confirmedAt;
  final String? scheduledPaymentDate;
  final List<String>? _transferProofUrlsCached;

  bool get isUnpaid => method == 'unpaid';
  bool get isCollecting => method == 'cash' || method == 'bank_transfer';
  bool get isPending => recordStatus == 'pending';
  bool get isConfirmed => recordStatus == 'confirmed';

  List<String> get proofImageUrls {
    if (_transferProofUrlsCached != null) return _transferProofUrlsCached;
    final t = (transferProofUrl ?? '').trim();
    if (t.isEmpty) return const [];
    if (t.startsWith('[')) {
      try {
        final parsed = jsonDecode(t);
        if (parsed is List) {
          return [
            for (final e in parsed)
              if (e is String && e.trim().isNotEmpty) e.trim(),
          ];
        }
      } catch (_) {}
      return const [];
    }
    return [t];
  }

  factory ServiceTicketPaymentPublic.fromJson(Map<String, dynamic> json) {
    final urlsRaw = json['transferProofUrls'];
    List<String>? urls;
    if (urlsRaw is List) {
      urls = [
        for (final e in urlsRaw)
          if (e is String && e.trim().isNotEmpty) e.trim(),
      ];
    }
    final reqRaw = json['requestedBy'];
    final confRaw = json['confirmedBy'];
    return ServiceTicketPaymentPublic(
      id: json['id'] as String,
      method: json['method'] as String? ?? '',
      methodLabel: json['methodLabel'] as String?,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      statusLabel: json['statusLabel'] as String?,
      transDate: json['transDate'] as String?,
      description: json['description'] as String?,
      transferProofUrl: json['transferProofUrl'] as String?,
      transferProofUrlsCached: urls,
      recordStatus: json['recordStatus'] as String?,
      requestedBy: reqRaw is Map<String, dynamic>
          ? TicketUserBrief.fromJson(reqRaw)
          : null,
      confirmedBy: confRaw is Map<String, dynamic>
          ? TicketUserBrief.fromJson(confRaw)
          : null,
      confirmedAt: json['confirmedAt'] as String?,
      scheduledPaymentDate: json['scheduledPaymentDate'] as String?,
    );
  }
}

class ServiceTicketPublic {
  const ServiceTicketPublic({
    required this.id,
    this.code,
    required this.requestId,
    required this.type,
    this.previousTicketId,
    required this.staffUserId,
    this.staffName,
    this.feeAmount = 0,
    this.isFree = true,
    this.costMode,
    this.freeReason,
    this.paymentMethod,
    this.costNote,
    this.costItems = const [],
    this.payments = const [],
    this.outstandingDue,
    this.hasConfirmedCollectingPayment = false,
    this.appointmentDate,
    this.appointmentSlot,
    this.note,
    required this.status,
    this.deadlineAt,
    this.contactFailedCount = 0,
    this.lastContactAttemptAt,
    this.isOverdue = false,
    this.guideContent,
    this.resultNote,
    this.productCondition,
    this.workDone,
    this.accessoriesNote,
    this.createdByUserId,
    this.statusChangedAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.request,
    this.repairDetail,
    this.evidences = const [],
    this.logs = const [],
    this.signatures = const [],
  });

  final String id;
  final String? code;
  final String requestId;
  final String type;
  final String? previousTicketId;
  final String staffUserId;
  final String? staffName;
  final int feeAmount;
  final bool isFree;
  final String? costMode;
  final String? freeReason;
  final String? paymentMethod;
  final String? costNote;
  final List<TicketCostItem> costItems;
  final List<ServiceTicketPaymentPublic> payments;
  final int? outstandingDue;
  final bool hasConfirmedCollectingPayment;
  final String? appointmentDate;
  final String? appointmentSlot;
  final String? note;
  final String status;
  final String? deadlineAt;
  final int contactFailedCount;
  final String? lastContactAttemptAt;
  final bool isOverdue;
  final String? guideContent;
  final String? resultNote;
  final String? productCondition;
  final String? workDone;
  final String? accessoriesNote;
  final String? createdByUserId;
  final String? statusChangedAt;
  final String? createdAt;
  final String? updatedAt;
  final String? deletedAt;
  final ServiceRequestBrief? request;
  final RepairDetailPublic? repairDetail;
  final List<TicketEvidencePublic> evidences;
  final List<TicketLogPublic> logs;
  final List<TicketSignaturePublic> signatures;

  bool get isDeleted => deletedAt != null && deletedAt!.trim().isNotEmpty;

  String get displayCode =>
      code ?? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id);

  bool get isPaidCollecting =>
      hasConfirmedCollectingPayment ||
      payments.any((p) => p.isCollecting && p.isConfirmed);

  int get displayAmountDue {
    if (outstandingDue != null) return outstandingDue! < 0 ? 0 : outstandingDue!;
    final subtracted = payments
        .where((p) => p.isCollecting)
        .fold<int>(0, (s, p) => s + p.amount);
    final rem = feeAmount - subtracted;
    return rem < 0 ? 0 : rem;
  }

  bool get hasPendingPayment => payments.any((p) => p.isPending);

  bool get isCostFree => costMode == 'free' || feeAmount <= 0;

  bool get canRecordOnsitePayment {
    if (isCostFree) return false;
    if (status == 'cancelled' || status == 'failed' || status == 'taken') {
      return false;
    }
    if (isPaidCollecting) return hasPendingPayment;
    return true;
  }

  factory ServiceTicketPublic.fromJson(Map<String, dynamic> json) {
    final reqRaw = json['request'];
    final detailRaw = json['repairDetail'];
    final evRaw = json['evidences'];
    final logRaw = json['logs'];
    final sigRaw = json['signatures'];
    final itemsRaw = json['costItems'];
    final payRaw = json['payments'];
    return ServiceTicketPublic(
      id: json['id'] as String,
      code: json['code'] as String?,
      requestId: json['requestId'] as String? ?? '',
      type: json['type'] as String? ?? 'online',
      previousTicketId: json['previousTicketId'] as String?,
      staffUserId: json['staffUserId'] as String? ?? '',
      staffName: json['staffName'] as String?,
      feeAmount: (json['feeAmount'] as num?)?.toInt() ?? 0,
      isFree: json['isFree'] as bool? ?? true,
      costMode: json['costMode'] as String?,
      freeReason: json['freeReason'] as String?,
      paymentMethod: json['paymentMethod'] as String?,
      costNote: json['costNote'] as String?,
      costItems: itemsRaw is List
          ? [
              for (final e in itemsRaw)
                if (e is Map<String, dynamic>) TicketCostItem.fromJson(e),
            ]
          : const [],
      payments: payRaw is List
          ? [
              for (final e in payRaw)
                if (e is Map<String, dynamic>)
                  ServiceTicketPaymentPublic.fromJson(e),
            ]
          : const [],
      outstandingDue: (json['outstandingDue'] as num?)?.toInt(),
      hasConfirmedCollectingPayment:
          json['hasConfirmedCollectingPayment'] as bool? ?? false,
      appointmentDate: json['appointmentDate'] as String?,
      appointmentSlot: json['appointmentSlot'] as String?,
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'processing',
      deadlineAt: json['deadlineAt'] as String?,
      contactFailedCount: (json['contactFailedCount'] as num?)?.toInt() ?? 0,
      lastContactAttemptAt: json['lastContactAttemptAt'] as String?,
      isOverdue: json['isOverdue'] as bool? ?? false,
      guideContent: json['guideContent'] as String?,
      resultNote: json['resultNote'] as String?,
      productCondition: json['productCondition'] as String?,
      workDone: json['workDone'] as String?,
      accessoriesNote: json['accessoriesNote'] as String?,
      createdByUserId: json['createdByUserId'] as String?,
      statusChangedAt: json['statusChangedAt'] as String?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
      deletedAt: json['deletedAt'] as String?,
      request: reqRaw is Map<String, dynamic>
          ? ServiceRequestBrief.fromJson(reqRaw)
          : null,
      repairDetail: detailRaw is Map<String, dynamic>
          ? RepairDetailPublic.fromJson(detailRaw)
          : null,
      evidences: evRaw is List
          ? [
              for (final e in evRaw)
                if (e is Map<String, dynamic>) TicketEvidencePublic.fromJson(e),
            ]
          : const [],
      logs: logRaw is List
          ? [
              for (final e in logRaw)
                if (e is Map<String, dynamic>) TicketLogPublic.fromJson(e),
            ]
          : const [],
      signatures: sigRaw is List
          ? [
              for (final e in sigRaw)
                if (e is Map<String, dynamic>)
                  TicketSignaturePublic.fromJson(e),
            ]
          : const [],
    );
  }
}

class ServiceRequestsListResult {
  const ServiceRequestsListResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<ServiceRequestPublic> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  factory ServiceRequestsListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return ServiceRequestsListResult(
      items: raw is List
          ? [
              for (final e in raw)
                if (e is Map<String, dynamic>) ServiceRequestPublic.fromJson(e),
            ]
          : const [],
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

class RepairSupportStats {
  const RepairSupportStats({
    required this.repairs,
    required this.support,
    this.scope = 'mine',
  });

  final RepairTicketStats repairs;
  final SupportTicketStats support;
  final String scope;

  factory RepairSupportStats.fromJson(Map<String, dynamic> json) {
    return RepairSupportStats(
      scope: json['scope'] as String? ?? 'mine',
      repairs: RepairTicketStats.fromJson(
        json['repairs'] as Map<String, dynamic>? ?? {},
      ),
      support: SupportTicketStats.fromJson(
        json['support'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class RepairTicketStats {
  const RepairTicketStats({
    this.openCount = 0,
    this.receivedToday = 0,
    this.overdue = 0,
    this.awaitingApproval = 0,
    this.awaitingPaymentConfirm = 0,
  });

  final int openCount;
  final int receivedToday;
  final int overdue;
  final int awaitingApproval;
  final int awaitingPaymentConfirm;

  factory RepairTicketStats.fromJson(Map<String, dynamic> json) {
    return RepairTicketStats(
      openCount: (json['openCount'] as num?)?.toInt() ?? 0,
      receivedToday: (json['receivedToday'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      awaitingApproval: (json['awaitingApproval'] as num?)?.toInt() ?? 0,
      awaitingPaymentConfirm:
          (json['awaitingPaymentConfirm'] as num?)?.toInt() ?? 0,
    );
  }
}

class SupportTicketStats {
  const SupportTicketStats({
    this.openCount = 0,
    this.newToday = 0,
    this.overdue = 0,
    this.customerRejectPending = 0,
  });

  final int openCount;
  final int newToday;
  final int overdue;
  final int customerRejectPending;

  factory SupportTicketStats.fromJson(Map<String, dynamic> json) {
    return SupportTicketStats(
      openCount: (json['openCount'] as num?)?.toInt() ?? 0,
      newToday: (json['newToday'] as num?)?.toInt() ?? 0,
      overdue: (json['overdue'] as num?)?.toInt() ?? 0,
      customerRejectPending:
          (json['customerRejectPending'] as num?)?.toInt() ?? 0,
    );
  }
}

class TakeDeviceResult {
  const TakeDeviceResult({
    required this.onsite,
    required this.repairTicket,
    this.repairRequest,
  });

  final ServiceTicketPublic onsite;
  final ServiceTicketPublic repairTicket;
  final ServiceRequestPublic? repairRequest;

  factory TakeDeviceResult.fromJson(Map<String, dynamic> json) {
    final repairRaw = json['repairTicket'] ?? json['repair'];
    return TakeDeviceResult(
      onsite: ServiceTicketPublic.fromJson(
        json['onsite'] as Map<String, dynamic>? ?? {},
      ),
      repairTicket: ServiceTicketPublic.fromJson(
        repairRaw as Map<String, dynamic>? ?? {},
      ),
      repairRequest: json['repairRequest'] is Map<String, dynamic>
          ? ServiceRequestPublic.fromJson(
              json['repairRequest'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
