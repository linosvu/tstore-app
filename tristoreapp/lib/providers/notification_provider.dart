import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/services/notification_storage.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/storage_service.dart';
import '../core/utils/uuid_util.dart';
import '../models/app_notification.dart';

const _seededKey = 'app_notifications_seeded_debug';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _items = [];
  bool _loaded = false;

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => n.isUnread).length;

  Future<void> load() async {
    final stored = await NotificationStorage.loadAll();
    _items
      ..clear()
      ..addAll(_sanitizeStored(stored));

    if (kDebugMode && _items.isEmpty) {
      final seeded = StorageService.instance.containsKey(_seededKey);
      if (!seeded) {
        _seedDemoNotifications();
        await StorageService.instance.saveBool(_seededKey, true);
        await _persist();
      }
    }

    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _loaded = true;
    final hadInvalidIds = stored.any(
      (n) => n.entityId != null && !isUuidV4Like(n.entityId),
    );
    if (hadInvalidIds) await _persist();
    await _syncBadge();
    notifyListeners();
  }

  /// Tải lại từ storage (sau background push).
  Future<void> reloadFromStorage() async {
    if (!_loaded) return;
    final stored = await NotificationStorage.loadAll();
    _items
      ..clear()
      ..addAll(_sanitizeStored(stored));
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final hadInvalidIds = stored.any(
      (n) => n.entityId != null && !isUuidV4Like(n.entityId),
    );
    if (hadInvalidIds) await _persist();
    await _syncBadge();
    notifyListeners();
  }

  List<AppNotification> _sanitizeStored(List<AppNotification> stored) {
    return [
      for (final n in stored)
        if (n.entityId != null && !isUuidV4Like(n.entityId))
          n.copyWith(clearEntityId: true)
        else
          n,
    ];
  }

  void _seedDemoNotifications() {
    final now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: 'demo-order-1',
        title: 'Đơn hàng mới từ KiotViet',
        body: '#DH2401 — Nguyễn Văn A',
        category: AppNotificationCategory.order,
        orderCode: 'DH2401',
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      AppNotification(
        id: 'demo-prep-1',
        title: 'Chuẩn bị hàng — phân công mới',
        body: 'Đơn #DH2398 được giao chuẩn bị',
        category: AppNotificationCategory.preparation,
        orderCode: 'DH2398',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'demo-order-2',
        title: 'Ghi nhận thanh toán mới',
        body: 'Đơn #DH2395 — 1.500.000 đ chờ duyệt',
        category: AppNotificationCategory.order,
        orderCode: 'DH2395',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: 'demo-delivery-1',
        title: 'Nhắc nhở giao hàng',
        body: 'Đơn #DH2390 — dự kiến giao lúc 14:30',
        category: AppNotificationCategory.delivery,
        orderCode: 'DH2390',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  Future<void> add(AppNotification notification) async {
    if (_items.any((n) => n.id == notification.id)) return;
    _items.insert(0, notification);
    await _persist();
    await _syncBadge();
    notifyListeners();
  }

  Future<void> addFromRemoteMessage(RemoteMessage message) async {
    await NotificationStorage.persistFromRemoteMessage(message);
    if (!_loaded) return;
    final stored = await NotificationStorage.loadAll();
    _items
      ..clear()
      ..addAll(_sanitizeStored(stored));
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _syncBadge();
    notifyListeners();
  }

  static Future<bool> persistFromRemoteMessage(RemoteMessage message) {
    return NotificationStorage.persistFromRemoteMessage(message);
  }

  Future<void> markReadFromPayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return;
      final fcmId = decoded['fcmMessageId'] as String?;
      if (fcmId != null && fcmId.isNotEmpty) {
        await markRead(fcmId);
      }
    } catch (_) {
      // ignore malformed payload
    }
  }

  Future<void> markReadFromRemoteMessage(RemoteMessage message) async {
    final id = NotificationStorage.idForRemoteMessage(message);
    await markRead(id);
  }

  Future<void> markRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index >= 0) {
      if (_items[index].readAt != null) return;
      _items[index] = _items[index].copyWith(readAt: DateTime.now());
      await _persist();
    } else {
      final stored = await NotificationStorage.loadAll();
      final sIndex = stored.indexWhere((n) => n.id == id);
      if (sIndex < 0 || stored[sIndex].readAt != null) return;
      stored[sIndex]
          = stored[sIndex].copyWith(readAt: DateTime.now());
      await _saveItems(stored);
      if (_loaded) {
        _items
          ..clear()
          ..addAll(_sanitizeStored(stored));
        _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    }
    await PushNotificationService.instance.dismissTrayNotification(id);
    await _syncBadge();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final now = DateTime.now();
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].readAt == null) {
        _items[i] = _items[i].copyWith(readAt: now);
      }
    }
    await _persist();
    await PushNotificationService.instance.dismissAllLocalTrayNotifications();
    await _syncBadge();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _items.removeWhere((n) => n.id == id);
    await _persist();
    await PushNotificationService.instance.dismissTrayNotification(id);
    await _syncBadge();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    _items.clear();
    await _persist();
    await PushNotificationService.instance.dismissAllLocalTrayNotifications();
    await _syncBadge();
    notifyListeners();
  }

  Future<void> _syncBadge() async {
    await PushNotificationService.instance.syncApplicationBadge(unreadCount);
  }

  Future<void> _persist() async {
    await _saveItems(_items);
  }

  Future<void> _saveItems(List<AppNotification> items) async {
    await StorageService.instance.saveString(
      notificationStorageKey,
      jsonEncode(items.map((n) => n.toJson()).toList()),
    );
  }
}
