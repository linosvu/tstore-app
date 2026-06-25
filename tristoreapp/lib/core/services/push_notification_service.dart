import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Xử lý background messages (phải là top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

/// Quản lý FCM token và lắng nghe thông báo.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Gọi khi nhận push lúc app đang foreground (gán từ [NotificationProvider]).
  Future<void> Function(RemoteMessage message)? onForegroundMessage;

  /// Gọi sau khi Firebase đã initializeApp().
  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  /// Lấy FCM token hiện tại. Trả về null nếu chưa sẵn sàng.
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  /// Callback khi token thay đổi (app cần đăng ký lại với server).
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint(
      '[FCM] Foreground: ${message.notification?.title} — ${message.notification?.body}',
    );
    final handler = onForegroundMessage;
    if (handler != null) {
      unawaited(handler(message));
    }
  }
}
