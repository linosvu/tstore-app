/// Ticket hỗ trợ khách hàng từ `/admin/support-tickets`.
class SupportTicketPublic {
  const SupportTicketPublic({
    required this.id,
    required this.ticketCode,
    required this.subject,
    required this.description,
    required this.category,
    required this.status,
    required this.priority,
    this.customerId,
    this.customer,
    required this.customerName,
    this.customerPhone,
    this.assignedUserId,
    this.assignedUser,
    this.repairOrderId,
    this.activityLog = const [],
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.statusChangedAt,
  });

  final String id;
  final String ticketCode;
  final String subject;
  final String description;
  final String category;
  final String status;
  final String priority;
  final String? customerId;
  final SupportTicketCustomerBrief? customer;
  final String customerName;
  final String? customerPhone;
  final String? assignedUserId;
  final SupportTicketUserBrief? assignedUser;
  final String? repairOrderId;
  final List<SupportActivityRecord> activityLog;
  final String createdByUserId;
  final String createdAt;
  final String updatedAt;
  final String? statusChangedAt;

  factory SupportTicketPublic.fromJson(Map<String, dynamic> json) {
    final custRaw = json['customer'];
    final assignedRaw = json['assignedUser'];
    final logRaw = json['activityLog'];
    return SupportTicketPublic(
      id: json['id'] as String,
      ticketCode: json['ticketCode'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'normal',
      customerId: json['customerId'] as String?,
      customer: custRaw is Map<String, dynamic>
          ? SupportTicketCustomerBrief.fromJson(custRaw)
          : null,
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String?,
      assignedUserId: json['assignedUserId'] as String?,
      assignedUser: assignedRaw is Map<String, dynamic>
          ? SupportTicketUserBrief.fromJson(assignedRaw)
          : null,
      repairOrderId: json['repairOrderId'] as String?,
      activityLog: logRaw is List
          ? [
              for (final e in logRaw)
                if (e is Map<String, dynamic>)
                  SupportActivityRecord.fromJson(e),
            ]
          : const [],
      createdByUserId: json['createdByUserId'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      statusChangedAt: json['statusChangedAt'] as String?,
    );
  }
}

class SupportTicketCustomerBrief {
  const SupportTicketCustomerBrief({
    required this.id,
    required this.name,
    this.phone,
    this.isVip = false,
  });

  final String id;
  final String name;
  final String? phone;
  final bool isVip;

  factory SupportTicketCustomerBrief.fromJson(Map<String, dynamic> json) {
    return SupportTicketCustomerBrief(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      isVip: json['isVip'] as bool? ?? false,
    );
  }
}

class SupportTicketUserBrief {
  const SupportTicketUserBrief({
    required this.id,
    required this.name,
    this.email,
  });

  final String id;
  final String name;
  final String? email;

  factory SupportTicketUserBrief.fromJson(Map<String, dynamic> json) {
    return SupportTicketUserBrief(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

class SupportActivityRecord {
  const SupportActivityRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final String content;
  final String createdAt;

  factory SupportActivityRecord.fromJson(Map<String, dynamic> json) {
    return SupportActivityRecord(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? 'note',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class SupportTicketsListResult {
  const SupportTicketsListResult({
    required this.items,
    required this.totalPages,
    required this.total,
  });

  final List<SupportTicketPublic> items;
  final int totalPages;
  final int total;

  factory SupportTicketsListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List
        ? raw
            .map((e) => SupportTicketPublic.fromJson(e as Map<String, dynamic>))
            .toList()
        : <SupportTicketPublic>[];
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final limit = (json['limit'] as num?)?.toInt() ?? 20;
    final pages = (json['totalPages'] as num?)?.toInt() ??
        ((total / limit).ceil().clamp(1, 9999));
    return SupportTicketsListResult(
      items: list,
      totalPages: pages,
      total: total,
    );
  }
}

class ConvertToRepairResult {
  const ConvertToRepairResult({
    required this.ticket,
    required this.repairOrder,
  });

  final SupportTicketPublic ticket;
  final Map<String, dynamic> repairOrder;

  factory ConvertToRepairResult.fromJson(Map<String, dynamic> json) {
    return ConvertToRepairResult(
      ticket: SupportTicketPublic.fromJson(
        json['ticket'] as Map<String, dynamic>,
      ),
      repairOrder: json['repairOrder'] as Map<String, dynamic>,
    );
  }
}
