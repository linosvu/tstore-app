class DashboardPaymentRecord {
  const DashboardPaymentRecord({
    required this.id,
    required this.source,
    required this.parentId,
    required this.parentCode,
    required this.recordStatus,
    required this.amount,
    required this.parentAmountDue,
    required this.createdAt,
    this.managerName,
  });

  final String id;
  /// sale_order | onsite | repair
  final String source;
  final String parentId;
  final String parentCode;
  /// pending | confirmed | awaiting_approval
  final String recordStatus;
  final int amount;
  /// Còn phải thu của đơn/phiếu cha.
  final int parentAmountDue;
  final DateTime createdAt;
  final String? managerName;

  factory DashboardPaymentRecord.fromJson(Map<String, dynamic> json) {
    return DashboardPaymentRecord(
      id: json['id'] as String? ?? '',
      source: json['source'] as String? ?? 'sale_order',
      parentId: json['parentId'] as String? ?? '',
      parentCode: json['parentCode'] as String? ?? '',
      recordStatus: json['recordStatus'] as String? ?? 'pending',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      parentAmountDue: (json['parentAmountDue'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      managerName: json['managerName'] as String?,
    );
  }

  String get recordStatusLabelVi {
    switch (recordStatus) {
      case 'pending':
        return 'Chờ duyệt';
      case 'awaiting_approval':
        return 'Chờ duyệt SC';
      case 'confirmed':
        return 'Đã xác nhận';
      default:
        return recordStatus;
    }
  }
}

class DashboardPaymentRecordsPage {
  const DashboardPaymentRecordsPage({
    required this.items,
    required this.total,
    required this.todayPendingCount,
    required this.page,
    required this.limit,
  });

  final List<DashboardPaymentRecord> items;
  final int total;
  final int todayPendingCount;
  final int page;
  final int limit;

  factory DashboardPaymentRecordsPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => DashboardPaymentRecord.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <DashboardPaymentRecord>[];
    return DashboardPaymentRecordsPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      todayPendingCount: (json['todayPendingCount'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
    );
  }
}
