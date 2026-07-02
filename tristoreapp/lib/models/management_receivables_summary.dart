class ManagementReceivablesSummary {
  const ManagementReceivablesSummary({
    required this.unpaid,
    required this.scheduledDelivery,
    required this.pendingApproval,
  });

  final ReceivableBucket unpaid;
  final ReceivableBucket scheduledDelivery;
  final ReceivableBucket pendingApproval;

  factory ManagementReceivablesSummary.fromJson(Map<String, dynamic> json) {
    return ManagementReceivablesSummary(
      unpaid: ReceivableBucket.fromJson(
        json['unpaid'] as Map<String, dynamic>? ?? const {},
      ),
      scheduledDelivery: ReceivableBucket.fromJson(
        json['scheduledDelivery'] as Map<String, dynamic>? ?? const {},
      ),
      pendingApproval: ReceivableBucket.fromJson(
        json['pendingApproval'] as Map<String, dynamic>? ?? const {},
        pendingAmountKey: 'totalPendingAmount',
      ),
    );
  }
}

class ReceivableBucket {
  const ReceivableBucket({
    required this.count,
    this.totalAmountDue,
    this.totalPendingAmount,
  });

  final int count;
  final int? totalAmountDue;
  final int? totalPendingAmount;

  int? get displayAmount => totalAmountDue ?? totalPendingAmount;

  factory ReceivableBucket.fromJson(
    Map<String, dynamic> json, {
    String pendingAmountKey = 'totalAmountDue',
  }) {
    return ReceivableBucket(
      count: (json['count'] as num?)?.toInt() ?? 0,
      totalAmountDue: pendingAmountKey == 'totalAmountDue'
          ? (json['totalAmountDue'] as num?)?.toInt()
          : null,
      totalPendingAmount: pendingAmountKey == 'totalPendingAmount'
          ? (json['totalPendingAmount'] as num?)?.toInt()
          : null,
    );
  }
}
