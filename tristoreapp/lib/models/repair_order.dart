/// Đơn sửa chữa từ `/admin/repair-orders`.
class RepairOrderPublic {
  const RepairOrderPublic({
    required this.id,
    this.repairCode,
    this.customerId,
    this.customer,
    required this.customerName,
    this.customerPhone,
    required this.itemDescription,
    required this.issueDescription,
    required this.status,
    required this.priority,
    this.receivedDate,
    this.promisedDate,
    this.notes,
    this.assignedUserId,
    this.assignedUser,
    this.supportTicketId,
    this.activityLog = const [],
    this.isOverdue = false,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.statusChangedAt,
  });

  final String id;
  final String? repairCode;
  final String? customerId;
  final RepairOrderCustomerBrief? customer;
  final String customerName;
  final String? customerPhone;
  final String itemDescription;
  final String issueDescription;
  final String status;
  final String priority;
  final String? receivedDate;
  final String? promisedDate;
  final String? notes;
  final String? assignedUserId;
  final RepairOrderUserBrief? assignedUser;
  final String? supportTicketId;
  final List<RepairActivityRecord> activityLog;
  final bool isOverdue;
  final String createdByUserId;
  final String createdAt;
  final String updatedAt;
  final String? statusChangedAt;

  String get displayCode => repairCode ?? id.substring(0, 8).toUpperCase();

  factory RepairOrderPublic.fromJson(Map<String, dynamic> json) {
    final custRaw = json['customer'];
    final assignedRaw = json['assignedUser'];
    final logRaw = json['activityLog'];
    return RepairOrderPublic(
      id: json['id'] as String,
      repairCode: json['repairCode'] as String?,
      customerId: json['customerId'] as String?,
      customer: custRaw is Map<String, dynamic>
          ? RepairOrderCustomerBrief.fromJson(custRaw)
          : null,
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String?,
      itemDescription: json['itemDescription'] as String? ?? '',
      issueDescription: json['issueDescription'] as String? ?? '',
      status: json['status'] as String? ?? 'received',
      priority: json['priority'] as String? ?? 'normal',
      receivedDate: json['receivedDate'] as String?,
      promisedDate: json['promisedDate'] as String?,
      notes: json['notes'] as String?,
      assignedUserId: json['assignedUserId'] as String?,
      assignedUser: assignedRaw is Map<String, dynamic>
          ? RepairOrderUserBrief.fromJson(assignedRaw)
          : null,
      supportTicketId: json['supportTicketId'] as String?,
      activityLog: logRaw is List
          ? [
              for (final e in logRaw)
                if (e is Map<String, dynamic>)
                  RepairActivityRecord.fromJson(e),
            ]
          : const [],
      isOverdue: json['isOverdue'] as bool? ?? false,
      createdByUserId: json['createdByUserId'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      statusChangedAt: json['statusChangedAt'] as String?,
    );
  }
}

class RepairOrderCustomerBrief {
  const RepairOrderCustomerBrief({
    required this.id,
    required this.name,
    this.phone,
    this.isVip = false,
  });

  final String id;
  final String name;
  final String? phone;
  final bool isVip;

  factory RepairOrderCustomerBrief.fromJson(Map<String, dynamic> json) {
    return RepairOrderCustomerBrief(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
      isVip: json['isVip'] as bool? ?? false,
    );
  }
}

class RepairOrderUserBrief {
  const RepairOrderUserBrief({
    required this.id,
    required this.name,
    this.email,
  });

  final String id;
  final String name;
  final String? email;

  factory RepairOrderUserBrief.fromJson(Map<String, dynamic> json) {
    return RepairOrderUserBrief(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

class RepairActivityRecord {
  const RepairActivityRecord({
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

  factory RepairActivityRecord.fromJson(Map<String, dynamic> json) {
    return RepairActivityRecord(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? 'note',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }
}

class RepairOrdersListResult {
  const RepairOrdersListResult({
    required this.items,
    required this.totalPages,
    required this.total,
  });

  final List<RepairOrderPublic> items;
  final int totalPages;
  final int total;

  factory RepairOrdersListResult.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final list = raw is List
        ? raw
            .map((e) => RepairOrderPublic.fromJson(e as Map<String, dynamic>))
            .toList()
        : <RepairOrderPublic>[];
    final total = (json['total'] as num?)?.toInt() ?? 0;
    final limit = (json['limit'] as num?)?.toInt() ?? 20;
    final pages = (json['totalPages'] as num?)?.toInt() ??
        ((total / limit).ceil().clamp(1, 9999));
    return RepairOrdersListResult(
      items: list,
      totalPages: pages,
      total: total,
    );
  }
}

class RepairSupportStats {
  const RepairSupportStats({
    required this.repairs,
    required this.support,
    this.scope = 'mine',
  });

  final RepairStats repairs;
  final SupportStats support;
  final String scope;

  factory RepairSupportStats.fromJson(Map<String, dynamic> json) {
    return RepairSupportStats(
      scope: json['scope'] as String? ?? 'mine',
      repairs: RepairStats.fromJson(
        json['repairs'] as Map<String, dynamic>? ?? {},
      ),
      support: SupportStats.fromJson(
        json['support'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class RepairStats {
  const RepairStats({
    this.openCount = 0,
    this.receivedToday = 0,
    this.overduePromised = 0,
    this.waitingParts = 0,
    this.doneNotReturned = 0,
  });

  final int openCount;
  final int receivedToday;
  final int overduePromised;
  final int waitingParts;
  final int doneNotReturned;

  factory RepairStats.fromJson(Map<String, dynamic> json) {
    return RepairStats(
      openCount: (json['openCount'] as num?)?.toInt() ?? 0,
      receivedToday: (json['receivedToday'] as num?)?.toInt() ?? 0,
      overduePromised: (json['overduePromised'] as num?)?.toInt() ?? 0,
      waitingParts: (json['waitingParts'] as num?)?.toInt() ?? 0,
      doneNotReturned: (json['doneNotReturned'] as num?)?.toInt() ?? 0,
    );
  }
}

class SupportStats {
  const SupportStats({
    this.openCount = 0,
    this.newToday = 0,
    this.waitingCustomer = 0,
    this.unassigned = 0,
  });

  final int openCount;
  final int newToday;
  final int waitingCustomer;
  final int unassigned;

  factory SupportStats.fromJson(Map<String, dynamic> json) {
    return SupportStats(
      openCount: (json['openCount'] as num?)?.toInt() ?? 0,
      newToday: (json['newToday'] as num?)?.toInt() ?? 0,
      waitingCustomer: (json['waitingCustomer'] as num?)?.toInt() ?? 0,
      unassigned: (json['unassigned'] as num?)?.toInt() ?? 0,
    );
  }
}
