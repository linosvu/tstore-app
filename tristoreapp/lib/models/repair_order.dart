/// Đơn sửa chữa từ `GET/POST/PATCH /admin/repair-orders`.
class RepairOrderPublic {
  const RepairOrderPublic({
    required this.id,
    required this.customerName,
    this.customerPhone,
    required this.itemDescription,
    required this.issueDescription,
    required this.status,
    required this.priority,
    this.receivedDate,
    this.promisedDate,
    this.notes,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String customerName;
  final String? customerPhone;
  final String itemDescription;
  final String issueDescription;
  final String status;
  final String priority;
  final String? receivedDate;
  final String? promisedDate;
  final String? notes;
  final String createdByUserId;
  final String createdAt;
  final String updatedAt;

  factory RepairOrderPublic.fromJson(Map<String, dynamic> json) {
    return RepairOrderPublic(
      id: json['id'] as String,
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String?,
      itemDescription: json['itemDescription'] as String? ?? '',
      issueDescription: json['issueDescription'] as String? ?? '',
      status: json['status'] as String? ?? 'received',
      priority: json['priority'] as String? ?? 'normal',
      receivedDate: json['receivedDate'] as String?,
      promisedDate: json['promisedDate'] as String?,
      notes: json['notes'] as String?,
      createdByUserId: json['createdByUserId'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
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
