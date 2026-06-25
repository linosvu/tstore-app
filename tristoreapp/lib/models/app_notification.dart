enum AppNotificationCategory {
  system,
  order,
  preparation,
  delivery,
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
    this.readAt,
  });

  final String id;
  final String title;
  final String body;
  final AppNotificationCategory category;
  final String? entityId;
  final String? orderCode;
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
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      entityId: entityId ?? this.entityId,
      orderCode: orderCode ?? this.orderCode,
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
      readAt: json['readAt'] != null
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String) ??
          DateTime.now(),
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
      default:
        return AppNotificationCategory.system;
    }
  }
}
