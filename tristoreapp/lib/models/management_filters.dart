class ManagementFilters {
  const ManagementFilters({
    this.from,
    this.to,
    this.createdByUserId,
    this.createdByUserName,
    this.assignedUserId,
    this.assignedUserName,
    this.assigneeUnassigned,
    this.saleOrderCreatedByUserId,
    this.paymentFilter,
    this.expectedDeliveryFilter,
    this.hasScheduledDelivery,
    this.priority,
    this.status,
    this.statusIn,
    this.prepActive,
    this.deliveryActive,
    this.deliveryScheduledSoon,
  });

  final String? from;
  final String? to;
  final String? createdByUserId;
  final String? createdByUserName;
  final String? assignedUserId;
  final String? assignedUserName;
  final bool? assigneeUnassigned;
  final String? saleOrderCreatedByUserId;
  final String? paymentFilter;
  final String? expectedDeliveryFilter;
  final bool? hasScheduledDelivery;
  final String? priority;
  final String? status;
  final List<String>? statusIn;
  final bool? prepActive;
  final bool? deliveryActive;
  final bool? deliveryScheduledSoon;

  static const empty = ManagementFilters();

  int get activeCount {
    var n = 0;
    if (from != null || to != null) n++;
    if (createdByUserId != null) n++;
    if (assigneeUnassigned == true) {
      n++;
    } else if (assignedUserId != null) {
      n++;
    }
    if (saleOrderCreatedByUserId != null) n++;
    if (paymentFilter != null) n++;
    if (expectedDeliveryFilter != null) n++;
    if (hasScheduledDelivery == true) n++;
    if (priority != null) n++;
    if (status != null) n++;
    if (statusIn != null && statusIn!.isNotEmpty) n++;
    if (prepActive == true) n++;
    if (deliveryActive == true) n++;
    if (deliveryScheduledSoon == true) n++;
    return n;
  }

  bool get hasActiveFilters => activeCount > 0;

  ManagementFilters copyWith({
    String? from,
    String? to,
    bool clearFrom = false,
    bool clearTo = false,
    String? createdByUserId,
    String? createdByUserName,
    bool clearCreatedBy = false,
    String? assignedUserId,
    String? assignedUserName,
    bool clearAssigned = false,
    bool? assigneeUnassigned,
    bool clearAssigneeUnassigned = false,
    String? saleOrderCreatedByUserId,
    String? paymentFilter,
    bool clearPaymentFilter = false,
    String? expectedDeliveryFilter,
    bool clearExpectedDeliveryFilter = false,
    bool? hasScheduledDelivery,
    bool clearScheduled = false,
    String? priority,
    bool clearPriority = false,
    String? status,
    bool clearStatus = false,
    List<String>? statusIn,
    bool clearStatusIn = false,
    bool? prepActive,
    bool clearPrepActive = false,
    bool? deliveryActive,
    bool clearDeliveryActive = false,
    bool? deliveryScheduledSoon,
    bool clearDeliveryScheduledSoon = false,
  }) {
    return ManagementFilters(
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      createdByUserId:
          clearCreatedBy ? null : (createdByUserId ?? this.createdByUserId),
      createdByUserName:
          clearCreatedBy ? null : (createdByUserName ?? this.createdByUserName),
      assignedUserId:
          clearAssigned ? null : (assignedUserId ?? this.assignedUserId),
      assignedUserName:
          clearAssigned ? null : (assignedUserName ?? this.assignedUserName),
      assigneeUnassigned: clearAssigneeUnassigned
          ? null
          : (assigneeUnassigned ?? this.assigneeUnassigned),
      saleOrderCreatedByUserId:
          saleOrderCreatedByUserId ?? this.saleOrderCreatedByUserId,
      paymentFilter:
          clearPaymentFilter ? null : (paymentFilter ?? this.paymentFilter),
      expectedDeliveryFilter: clearExpectedDeliveryFilter
          ? null
          : (expectedDeliveryFilter ?? this.expectedDeliveryFilter),
      hasScheduledDelivery: clearScheduled
          ? null
          : (hasScheduledDelivery ?? this.hasScheduledDelivery),
      priority: clearPriority ? null : (priority ?? this.priority),
      status: clearStatus ? null : (status ?? this.status),
      statusIn: clearStatusIn ? null : (statusIn ?? this.statusIn),
      prepActive: clearPrepActive ? null : (prepActive ?? this.prepActive),
      deliveryActive:
          clearDeliveryActive ? null : (deliveryActive ?? this.deliveryActive),
      deliveryScheduledSoon: clearDeliveryScheduledSoon
          ? null
          : (deliveryScheduledSoon ?? this.deliveryScheduledSoon),
    );
  }

  Map<String, dynamic> toQueryParams({bool includeStatus = true}) {
    final q = <String, dynamic>{};
    if (from != null && from!.isNotEmpty) q['from'] = from;
    if (to != null && to!.isNotEmpty) q['to'] = to;
    if (createdByUserId != null && createdByUserId!.isNotEmpty) {
      q['createdByUserId'] = createdByUserId;
    }
    if (assigneeUnassigned == true) {
      q['assigneeUnassigned'] = true;
    } else if (assignedUserId != null && assignedUserId!.isNotEmpty) {
      q['assignedUserId'] = assignedUserId;
    }
    if (saleOrderCreatedByUserId != null &&
        saleOrderCreatedByUserId!.isNotEmpty) {
      q['saleOrderCreatedByUserId'] = saleOrderCreatedByUserId;
    }
    if (paymentFilter != null) q['paymentFilter'] = paymentFilter;
    if (expectedDeliveryFilter != null) {
      q['expectedDeliveryFilter'] = expectedDeliveryFilter;
    }
    if (hasScheduledDelivery == true) q['hasScheduledDelivery'] = true;
    if (priority != null) q['priority'] = priority;
    if (includeStatus && status != null) q['status'] = status;
    if (statusIn != null && statusIn!.isNotEmpty) {
      q['statusIn'] = statusIn!.join(',');
    }
    if (prepActive == true) q['prepActive'] = true;
    if (deliveryActive == true) q['deliveryActive'] = true;
    if (deliveryScheduledSoon == true) q['deliveryScheduledSoon'] = true;
    return q;
  }

  Map<String, dynamic> toJson() => {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (createdByUserId != null) 'createdByUserId': createdByUserId,
        if (createdByUserName != null) 'createdByUserName': createdByUserName,
        if (assignedUserId != null) 'assignedUserId': assignedUserId,
        if (assignedUserName != null) 'assignedUserName': assignedUserName,
        if (assigneeUnassigned == true) 'assigneeUnassigned': true,
        if (saleOrderCreatedByUserId != null)
          'saleOrderCreatedByUserId': saleOrderCreatedByUserId,
        if (paymentFilter != null) 'paymentFilter': paymentFilter,
        if (expectedDeliveryFilter != null)
          'expectedDeliveryFilter': expectedDeliveryFilter,
        if (hasScheduledDelivery == true) 'hasScheduledDelivery': true,
        if (priority != null) 'priority': priority,
        if (status != null) 'status': status,
        if (statusIn != null) 'statusIn': statusIn,
        if (prepActive == true) 'prepActive': true,
        if (deliveryActive == true) 'deliveryActive': true,
        if (deliveryScheduledSoon == true) 'deliveryScheduledSoon': true,
      };

  factory ManagementFilters.fromJson(Map<String, dynamic> json) {
    List<String>? statusIn;
    final rawStatusIn = json['statusIn'];
    if (rawStatusIn is List) {
      statusIn = rawStatusIn.map((e) => '$e').toList();
    } else if (rawStatusIn is String && rawStatusIn.isNotEmpty) {
      statusIn = rawStatusIn.split(',').map((s) => s.trim()).toList();
    }
    return ManagementFilters(
      from: json['from'] as String?,
      to: json['to'] as String?,
      createdByUserId: json['createdByUserId'] as String?,
      createdByUserName: json['createdByUserName'] as String?,
      assignedUserId: json['assignedUserId'] as String?,
      assignedUserName: json['assignedUserName'] as String?,
      assigneeUnassigned: json['assigneeUnassigned'] == true,
      saleOrderCreatedByUserId: json['saleOrderCreatedByUserId'] as String?,
      paymentFilter: json['paymentFilter'] as String?,
      expectedDeliveryFilter: json['expectedDeliveryFilter'] as String?,
      hasScheduledDelivery: json['hasScheduledDelivery'] == true,
      priority: json['priority'] as String?,
      status: json['status'] as String?,
      statusIn: statusIn,
      prepActive: json['prepActive'] == true,
      deliveryActive: json['deliveryActive'] == true,
      deliveryScheduledSoon: json['deliveryScheduledSoon'] == true,
    );
  }
}
