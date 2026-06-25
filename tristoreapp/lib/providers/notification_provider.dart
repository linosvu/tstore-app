import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/services/storage_service.dart';
import '../models/app_notification.dart';

const _storageKey = 'app_notifications_v1';
const _seededKey = 'app_notifications_seeded_debug';

class NotificationProvider extends ChangeNotifier {
  final List<AppNotification> _items = [];
  bool _loaded = false;

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => n.isUnread).length;

  Future<void> load() async {
    final raw = await StorageService.instance.getString(_storageKey);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final entry in list) {
          if (entry is Map<String, dynamic>) {
            _items.add(AppNotification.fromJson(entry));
          }
        }
      } catch (_) {
        _items.clear();
      }
    }

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
    notifyListeners();
  }

  void _seedDemoNotifications() {
    final now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: const Uuid().v4(),
        title: 'Đơn hàng mới từ KiotViet',
        body: '#DH2401 — Nguyễn Văn A',
        category: AppNotificationCategory.order,
        entityId: 'demo-order-1',
        orderCode: 'DH2401',
        createdAt: now.subtract(const Duration(minutes: 12)),
      ),
      AppNotification(
        id: const Uuid().v4(),
        title: 'Chuẩn bị hàng — phân công mới',
        body: 'Đơn #DH2398 được giao chuẩn bị',
        category: AppNotificationCategory.preparation,
        entityId: 'demo-prep-1',
        orderCode: 'DH2398',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: const Uuid().v4(),
        title: 'Ghi nhận thanh toán mới',
        body: 'Đơn #DH2395 — 1.500.000 đ chờ duyệt',
        category: AppNotificationCategory.order,
        entityId: 'demo-order-2',
        orderCode: 'DH2395',
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      AppNotification(
        id: const Uuid().v4(),
        title: 'Nhắc nhở giao hàng',
        body: 'Đơn #DH2390 — dự kiến giao lúc 14:30',
        category: AppNotificationCategory.delivery,
        entityId: 'demo-delivery-1',
        orderCode: 'DH2390',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  Future<void> add(AppNotification notification) async {
    _items.insert(0, notification);
    await _persist();
    notifyListeners();
  }

  Future<void> addFromRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'Thông báo';
    final body = notification?.body ?? data['body'] ?? '';
    final screen = data['screen'];
    final entityId = (data['entityId'] ?? data['orderId'])?.trim();
    final orderCode = data['orderCode']?.trim();

    await add(
      AppNotification(
        id: const Uuid().v4(),
        title: title,
        body: body,
        category: AppNotification.categoryFromScreen(screen),
        entityId: entityId != null && entityId.isNotEmpty ? entityId : null,
        orderCode: orderCode != null && orderCode.isNotEmpty ? orderCode : null,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> markRead(String id) async {
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0 || _items[index].readAt != null) return;
    _items[index] = _items[index].copyWith(readAt: DateTime.now());
    await _persist();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].isUnread) {
        _items[i] = _items[i].copyWith(readAt: now);
        changed = true;
      }
    }
    if (!changed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    final removed = _items.length;
    _items.removeWhere((n) => n.id == id);
    if (_items.length == removed) return;
    await _persist();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    if (_items.isEmpty) return;
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final encoded = jsonEncode(_items.map((n) => n.toJson()).toList());
    await StorageService.instance.saveString(_storageKey, encoded);
  }

  bool get isLoaded => _loaded;
}
