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
import 'service_ticket_open_screen.dart';

/// Điều hướng từ push notification hoặc tab Thông báo.
class NotificationNavigation {
  NotificationNavigation._();

  static bool openFromNotification(
    BuildContext context,
    AppNotification notification,
  ) {
    final entityId = notification.entityId;
    final category = _resolveCategory(
      notification.category,
      isTicketPayload: notification.ticketType?.isNotEmpty == true,
    );
    if (!_canNavigate(entityId) ||
        category == AppNotificationCategory.system) {
      _showInvalidTargetMessage(context);
      return false;
    }
    return _open(
      category: category,
      entityId: entityId!.trim(),
      ticketType: notification.ticketType,
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
    final ticketId = (data['ticketId'] as String?)?.trim();
    final entityId = (data['entityId'] as String? ??
            data['orderId'] as String? ??
            ticketId)
        ?.trim();
    final ticketType = (data['ticketType'] as String?)?.trim();
    final ctx = rootNavigatorKey.currentContext;

    final category = _resolveCategory(
      AppNotification.categoryFromScreen(screen),
      isTicketPayload:
          ticketType?.isNotEmpty == true || ticketId?.isNotEmpty == true,
    );
    if (!_canNavigate(entityId) ||
        category == AppNotificationCategory.system) {
      if (ctx != null) _showInvalidTargetMessage(ctx);
      return;
    }

    _open(
      category: category,
      entityId: entityId!,
      ticketType:
          ticketType != null && ticketType.isNotEmpty ? ticketType : null,
    );
  }

  /// Payload cũ chỉ có `ticketId` (chưa có `screen`) vẫn mở được phiếu.
  static AppNotificationCategory _resolveCategory(
    AppNotificationCategory category, {
    required bool isTicketPayload,
  }) {
    if (category != AppNotificationCategory.system) return category;
    return isTicketPayload
        ? AppNotificationCategory.serviceTicket
        : category;
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
    String? ticketType,
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
          case AppNotificationCategory.serviceTicket:
            return ServiceTicketOpenScreen(
              ticketId: entityId,
              ticketType: ticketType,
            );
          case AppNotificationCategory.system:
            return const SizedBox.shrink();
        }
      },
    );
    navigator.push(route);
    return true;
  }
}
