import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../screens/delivery/delivery_detail_screen.dart';
import '../../screens/orders/sale_order_detail_screen.dart';
import '../../screens/preparation/preparation_detail_screen.dart';
import '../utils/uuid_util.dart';
import '../widgets/app_messenger.dart';
import 'app_navigator.dart';

/// Điều hướng từ push notification hoặc tab Thông báo.
class NotificationNavigation {
  NotificationNavigation._();

  static bool openFromNotification(
    BuildContext context,
    AppNotification notification,
  ) {
    final entityId = notification.entityId;
    if (!_canNavigate(entityId)) {
      _showInvalidTargetMessage(context);
      return false;
    }
    return _open(
      category: notification.category,
      entityId: entityId!.trim(),
    );
  }

  static void openFromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;
    openFromDataMap(Map<String, dynamic>.from(data));
  }

  static void openFromPayload(String? payload) {
    if (payload == null || payload.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        openFromDataMap(decoded);
      }
    } catch (_) {
      // ignore malformed payload
    }
  }

  static void openFromDataMap(Map<String, dynamic> data) {
    final screen = data['screen'] as String?;
    final entityId =
        (data['entityId'] as String? ?? data['orderId'] as String?)?.trim();
    final ctx = rootNavigatorKey.currentContext;
    if (!_canNavigate(entityId)) {
      if (ctx != null) _showInvalidTargetMessage(ctx);
      return;
    }

    _open(
      category: AppNotification.categoryFromScreen(screen),
      entityId: entityId!,
    );
  }

  static bool _canNavigate(String? entityId) => isUuidV4Like(entityId);

  static void _showInvalidTargetMessage(BuildContext context) {
    AppMessenger.show(
      context,
      'Không mở được chi tiết — thông báo không có liên kết hợp lệ.',
    );
  }

  static bool _open({
    required AppNotificationCategory category,
    required String entityId,
  }) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return false;

    final route = MaterialPageRoute<void>(
      builder: (_) {
        switch (category) {
          case AppNotificationCategory.order:
            return SaleOrderDetailScreen(orderId: entityId);
          case AppNotificationCategory.preparation:
            return PreparationDetailScreen(preparationId: entityId);
          case AppNotificationCategory.delivery:
            return DeliveryDetailScreen(deliveryId: entityId);
          case AppNotificationCategory.system:
            return const SizedBox.shrink();
        }
      },
    );
    navigator.push(route);
    return true;
  }
}
