enum AppNotificationCategory {
  system,
  order,
  preparation,
  delivery,
  serviceTicket,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.entityId,
    this.orderCode,
    this.ticketType,
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final AppNotificationCategory category;
  final String? entityId;
  final String? orderCode;
  /// online | onsite | other | repair — dùng deep-link phiếu hỗ trợ/SC.
  final String? ticketType;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    AppNotificationCategory? category,
    String? entityId,
    String? orderCode,
    String? ticketType,
    DateTime? readAt,
    bool clearReadAt = false,
    bool clearEntityId = false,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      entityId: clearEntityId ? null : (entityId ?? this.entityId),
      orderCode: orderCode ?? this.orderCode,
      ticketType: ticketType ?? this.ticketType,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category.name,
        if (entityId != null) 'entityId': entityId,
        if (orderCode != null) 'orderCode': orderCode,
        if (ticketType != null) 'ticketType': ticketType,
        if (readAt != null) 'readAt': readAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: AppNotificationCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => AppNotificationCategory.system,
      ),
      entityId: json['entityId'] as String?,
      orderCode: json['orderCode'] as String?,
      ticketType: json['ticketType'] as String?,
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
    );
  }

  static AppNotificationCategory categoryFromScreen(String? screen) {
    switch (screen) {
      case 'order':
        return AppNotificationCategory.order;
      case 'preparation':
        return AppNotificationCategory.preparation;
      case 'delivery':
        return AppNotificationCategory.delivery;
      case 'service_ticket':
        return AppNotificationCategory.serviceTicket;
      default:
        return AppNotificationCategory.system;
    }
  }
}
