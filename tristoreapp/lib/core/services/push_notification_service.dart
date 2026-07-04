import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../navigation/notification_navigation.dart';
import 'notification_storage.dart';

const _androidChannelId = 'tstore_orders';
const _androidChannelName = 'Đơn hàng & vận hành';
const _badgeOnlyNotificationId = 999999;

/// Xử lý background messages (phải là top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationStorage.persistFromRemoteMessage(message);
  await PushNotificationService.syncApplicationBadgeFromStorage();
}

/// Quản lý FCM token, tray notification và điều hướng khi tap.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Gọi khi nhận push lúc app đang foreground (gán từ [NotificationProvider]).
  Future<void> Function(RemoteMessage message)? onForegroundMessage;

  /// Gọi khi user mở app từ push (tray / terminated).
  Future<void> Function(RemoteMessage message)? onNotificationOpened;

  /// Gọi khi user tap local notification (foreground tray).
  Future<void> Function(String? payload)? onPayloadOpened;

  StreamSubscription<RemoteMessage>? _openedAppSub;
  bool _initialized = false;

  /// Gọi sau khi Firebase đã initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    await _openedAppSub?.cancel();
    _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedRemoteMessage,
    );
  }

  Future<void> handleInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      await NotificationStorage.persistFromRemoteMessage(message);
      await onNotificationOpened?.call(message);
      NotificationNavigation.openFromRemoteMessage(message);
    }
  }

  /// Lấy FCM token hiện tại. Trả về null nếu chưa sẵn sàng.
  Future<String?> getToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS cần APNs token trước; nếu gọi quá sớm Firebase có thể trả null/lỗi.
        for (var i = 0; i < 10; i++) {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  /// Callback khi token thay đổi (app cần đăng ký lại với server).
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  /// Đồng bộ badge icon app (iOS) với số chưa đọc trong app.
  Future<void> syncApplicationBadge(int unreadCount) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    await _localNotifications.show(
      _badgeOnlyNotificationId,
      '',
      '',
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentList: false,
          presentSound: false,
          presentBadge: true,
          badgeNumber: unreadCount,
        ),
      ),
    );
    await _localNotifications.cancel(_badgeOnlyNotificationId);
  }

  /// Dùng trong background isolate — đọc storage rồi cập nhật badge.
  static Future<void> syncApplicationBadgeFromStorage() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    final unread = await NotificationStorage.unreadCount();
    final plugin = FlutterLocalNotificationsPlugin();
    const initSettings = InitializationSettings(
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(initSettings);
    await plugin.show(
      _badgeOnlyNotificationId,
      '',
      '',
      NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBanner: false,
          presentList: false,
          presentSound: false,
          presentBadge: true,
          badgeNumber: unread,
        ),
      ),
    );
    await plugin.cancel(_badgeOnlyNotificationId);
  }

  /// Gỡ thông báo khỏi tray (local notification do app hiển thị).
  Future<void> dismissTrayNotification(String notificationId) async {
    await _localNotifications.cancel(
      NotificationStorage.trayNotificationIdFor(notificationId),
    );
  }

  /// Gỡ tất cả local notification do app hiển thị (foreground).
  Future<void> dismissAllLocalTrayNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// iOS/Android có thể hiển thị remote push trong Notification Center khi app
  /// đang background mà Dart chưa kịp persist. Khi app quay lại foreground hoặc
  /// mở màn Thông báo, đồng bộ bù các notification đang còn trên tray.
  Future<bool> syncDeliveredNotificationsToStorage() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }

    final List<ActiveNotification> active;
    try {
      active = await _localNotifications.getActiveNotifications();
    } catch (e) {
      debugPrint('[Notifications] getActiveNotifications error: $e');
      return false;
    }
    var added = false;
    for (final notification in active) {
      final didAdd =
          await NotificationStorage.persistFromActiveNotification(notification);
      added = added || didAdd;
    }
    if (added) {
      await syncApplicationBadgeFromStorage();
    }
    return added;
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) async {
        await onPayloadOpened?.call(response.payload);
        NotificationNavigation.openFromPayload(response.payload);
      },
    );

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'Thông báo đơn hàng, chuẩn bị, giao hàng',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint(
      '[FCM] Foreground: ${message.notification?.title} — ${message.notification?.body}',
    );

    final handler = onForegroundMessage;
    if (handler != null) {
      await handler(message);
    }

    final unread = await NotificationStorage.unreadCount();
    await _showLocalNotification(message, badgeNumber: unread);
  }

  Future<void> _showLocalNotification(
    RemoteMessage message, {
    required int badgeNumber,
  }) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'Thông báo';
    final body = notification?.body ?? data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final notificationId = NotificationStorage.idForRemoteMessage(message);
    final payload = jsonEncode({
      ...data,
      'fcmMessageId': notificationId,
    });
    final trayId = NotificationStorage.trayNotificationIdFor(notificationId);

    await _localNotifications.show(
      trayId,
      title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: 'Thông báo đơn hàng, chuẩn bị, giao hàng',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          badgeNumber: badgeNumber,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _handleOpenedRemoteMessage(RemoteMessage message) async {
    await NotificationStorage.persistFromRemoteMessage(message);
    await onNotificationOpened?.call(message);
    NotificationNavigation.openFromRemoteMessage(message);
  }
}
