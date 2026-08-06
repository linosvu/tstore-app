/// Phiếu yêu cầu / phiếu con từ `/admin/service-requests` & `/admin/service-tickets`.
library;

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
    this.appointmentDate,
    this.appointmentSlot,
    this.deadlineAt,
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
  final String? appointmentDate;
  final String? appointmentSlot;
  final String? deadlineAt;
  final bool isOverdue;
  final String? statusChangedAt;
  final String? createdAt;

  String get displayCode =>
      code ?? (id.length >= 8 ? id.substring(0, 8).toUpperCase() : id);

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
      appointmentDate: json['appointmentDate'] as String?,
      appointmentSlot: json['appointmentSlot'] as String?,
      deadlineAt: json['deadlineAt'] as String?,
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
    this.appointmentDate,
    this.appointmentSlot,
    this.note,
    required this.status,
    this.deadlineAt,
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
  final String? appointmentDate;
  final String? appointmentSlot;
  final String? note;
  final String status;
  final String? deadlineAt;
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

  factory ServiceTicketPublic.fromJson(Map<String, dynamic> json) {
    final reqRaw = json['request'];
    final detailRaw = json['repairDetail'];
    final evRaw = json['evidences'];
    final logRaw = json['logs'];
    final sigRaw = json['signatures'];
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
      appointmentDate: json['appointmentDate'] as String?,
      appointmentSlot: json['appointmentSlot'] as String?,
      note: json['note'] as String?,
      status: json['status'] as String? ?? 'processing',
      deadlineAt: json['deadlineAt'] as String?,
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
