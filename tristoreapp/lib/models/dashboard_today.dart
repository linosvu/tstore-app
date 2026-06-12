class DashboardTodayResponse {
  const DashboardTodayResponse({
    required this.date,
    required this.scope,
    required this.todayOrders,
    required this.todayPreparations,
    required this.todayDeliveries,
    required this.reminderDraftOrTemp,
    required this.reminderPrepToDo,
    required this.reminderDeliveriesToDo,
    required this.reminderScheduledPayments,
    required this.reminderOverdueOrders,
    required this.reminderDueWithin24h,
    required this.reminderScheduledDeliveryWithin24h,
    required this.reminderOrdersWithoutPrepAssignee,
    required this.reminderDeliveriesWithoutAssignee,
  });

  final String date;
  final String scope;
  final int todayOrders;
  final int todayPreparations;
  final int todayDeliveries;
  final int reminderDraftOrTemp;
  final int reminderPrepToDo;
  final int reminderDeliveriesToDo;
  final int reminderScheduledPayments;
  final int reminderOverdueOrders;
  final int reminderDueWithin24h;
  final int reminderScheduledDeliveryWithin24h;
  final int reminderOrdersWithoutPrepAssignee;
  final int reminderDeliveriesWithoutAssignee;

  factory DashboardTodayResponse.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>? ?? {};
    final reminders = json['reminders'] as Map<String, dynamic>? ?? {};
    return DashboardTodayResponse(
      date: json['date'] as String? ?? '',
      scope: json['scope'] as String? ?? 'mine',
      todayOrders: (today['orders'] as num?)?.toInt() ?? 0,
      todayPreparations: (today['preparations'] as num?)?.toInt() ?? 0,
      todayDeliveries: (today['deliveries'] as num?)?.toInt() ?? 0,
      reminderDraftOrTemp:
          (reminders['draftOrTempOrders'] as num?)?.toInt() ?? 0,
      reminderPrepToDo:
          (reminders['preparationsToDo'] as num?)?.toInt() ?? 0,
      reminderDeliveriesToDo:
          (reminders['deliveriesToDo'] as num?)?.toInt() ?? 0,
      reminderScheduledPayments:
          (reminders['scheduledPaymentOrders'] as num?)?.toInt() ?? 0,
      reminderOverdueOrders: (reminders['overdueOrders'] as num?)?.toInt() ?? 0,
      reminderDueWithin24h: (reminders['dueWithin24h'] as num?)?.toInt() ?? 0,
      reminderScheduledDeliveryWithin24h:
          (reminders['scheduledDeliveryWithin24h'] as num?)?.toInt() ?? 0,
      reminderOrdersWithoutPrepAssignee:
          (reminders['ordersWithoutPrepAssignee'] as num?)?.toInt() ?? 0,
      reminderDeliveriesWithoutAssignee:
          (reminders['deliveriesWithoutAssignee'] as num?)?.toInt() ?? 0,
    );
  }
}
