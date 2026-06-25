import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_notification.dart';

const notificationStorageKey = 'app_notifications_v1';

/// Lưu thông báo vào SharedPreferences — dùng được cả background isolate.
class NotificationStorage {
  NotificationStorage._();

  static AppNotification notificationFromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'Thông báo';
    final body = notification?.body ?? data['body'] ?? '';
    final screen = data['screen'];
    final entityId = (data['entityId'] ?? data['orderId'])?.trim();
    final orderCode = data['orderCode']?.trim();

    return AppNotification(
      id: const Uuid().v4(),
      title: title,
      body: body,
      category: AppNotification.categoryFromScreen(screen),
      entityId: entityId != null && entityId.isNotEmpty ? entityId : null,
      orderCode: orderCode != null && orderCode.isNotEmpty ? orderCode : null,
      createdAt: DateTime.now(),
    );
  }

  static AppNotification notificationFromDataMap(Map<String, dynamic> data) {
    final title = data['title'] as String? ?? 'Thông báo';
    final body = data['body'] as String? ?? '';
    final screen = data['screen'] as String?;
    final entityId =
        (data['entityId'] as String? ?? data['orderId'] as String?)?.trim();
    final orderCode = data['orderCode'] as String?;

    return AppNotification(
      id: const Uuid().v4(),
      title: title,
      body: body,
      category: AppNotification.categoryFromScreen(screen),
      entityId: entityId != null && entityId.isNotEmpty ? entityId : null,
      orderCode: orderCode != null && orderCode.isNotEmpty ? orderCode : null,
      createdAt: DateTime.now(),
    );
  }

  static Future<List<AppNotification>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(notificationStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final entry in list)
          if (entry is Map<String, dynamic>)
            AppNotification.fromJson(entry),
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> persist(AppNotification notification) async {
    final items = await loadAll();
    items.insert(0, notification);
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      notificationStorageKey,
      jsonEncode(items.map((n) => n.toJson()).toList()),
    );
  }

  static Future<void> persistFromRemoteMessage(RemoteMessage message) async {
    await persist(notificationFromRemoteMessage(message));
  }
}
