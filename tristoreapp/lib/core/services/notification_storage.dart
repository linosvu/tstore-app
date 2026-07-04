import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_notification.dart';

const notificationStorageKey = 'app_notifications_v1';

/// Lưu thông báo vào SharedPreferences — dùng được cả background isolate.
class NotificationStorage {
  NotificationStorage._();

  static String idForRemoteMessage(RemoteMessage message) {
    final messageId = message.messageId?.trim();
    if (messageId != null && messageId.isNotEmpty) return messageId;
    return const Uuid().v4();
  }

  static int trayNotificationIdFor(String notificationId) =>
      notificationId.hashCode & 0x7fffffff;

  static String _stableHashId(String prefix, Iterable<String?> parts) {
    final source = parts.map((p) => p ?? '').join('|');
    return '$prefix:${sha1.convert(utf8.encode(source))}';
  }

  static AppNotificationCategory _categoryFromText(
    String? screen,
    String title,
    String body,
  ) {
    final fromScreen = AppNotification.categoryFromScreen(screen);
    if (fromScreen != AppNotificationCategory.system) return fromScreen;

    final text = '$title $body'.toLowerCase();
    if (text.contains('giao hàng')) return AppNotificationCategory.delivery;
    if (text.contains('chuẩn bị')) return AppNotificationCategory.preparation;
    if (text.contains('đơn') ||
        text.contains('kiotviet') ||
        text.contains('thanh toán')) {
      return AppNotificationCategory.order;
    }
    return AppNotificationCategory.system;
  }

  static Map<String, dynamic> _payloadData(String? payload) {
    if (payload == null || payload.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Remote APNS notifications usually do not expose plugin payload.
    }
    return {};
  }

  static AppNotification notificationFromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'Thông báo';
    final body = notification?.body ?? data['body'] ?? '';
    final screen = data['screen'];
    final entityId = (data['entityId'] ?? data['orderId'])?.trim();
    final orderCode = data['orderCode']?.trim();

    return AppNotification(
      id: idForRemoteMessage(message),
      title: title,
      body: body,
      category: AppNotification.categoryFromScreen(screen),
      entityId: entityId != null && entityId.isNotEmpty ? entityId : null,
      orderCode: orderCode != null && orderCode.isNotEmpty ? orderCode : null,
      createdAt: DateTime.now(),
    );
  }

  static AppNotification? notificationFromActiveNotification(
    ActiveNotification active,
  ) {
    final data = _payloadData(active.payload);
    final title = active.title ?? data['title'] as String? ?? 'Thông báo';
    final body =
        active.body ?? active.bigText ?? data['body'] as String? ?? '';
    if (title.trim().isEmpty && body.trim().isEmpty) return null;

    final screen = data['screen'] as String?;
    final entityId =
        (data['entityId'] as String? ?? data['orderId'] as String?)?.trim();
    final orderCode = data['orderCode'] as String?;
    final fcmMessageId = data['fcmMessageId'] as String?;
    final id = fcmMessageId != null && fcmMessageId.isNotEmpty
        ? fcmMessageId
        : _stableHashId(
            'active',
            [
              active.id?.toString(),
              active.tag,
              active.channelId,
              title,
              body,
              active.payload,
            ],
          );

    return AppNotification(
      id: id,
      title: title,
      body: body,
      category: _categoryFromText(screen, title, body),
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
          if (entry is Map<String, dynamic>) AppNotification.fromJson(entry),
      ];
    } catch (_) {
      return [];
    }
  }

  static int unreadCountFrom(List<AppNotification> items) =>
      items.where((n) => n.isUnread).length;

  static Future<int> unreadCount() async {
    final items = await loadAll();
    return unreadCountFrom(items);
  }

  /// Trả về `true` nếu thêm mới; `false` nếu đã có (tránh đếm trùng khi tap push).
  static Future<bool> persist(AppNotification notification) async {
    final items = await loadAll();
    if (items.any((n) => n.id == notification.id)) return false;
    items.insert(0, notification);
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      notificationStorageKey,
      jsonEncode(items.map((n) => n.toJson()).toList()),
    );
    return true;
  }

  static Future<bool> persistFromRemoteMessage(RemoteMessage message) async {
    return persist(notificationFromRemoteMessage(message));
  }

  static Future<bool> persistFromActiveNotification(
    ActiveNotification active,
  ) async {
    final notification = notificationFromActiveNotification(active);
    if (notification == null) return false;
    return persist(notification);
  }
}
