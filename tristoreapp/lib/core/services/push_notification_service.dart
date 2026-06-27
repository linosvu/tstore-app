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

/// Xử lý background messages (phải là top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationStorage.persistFromRemoteMessage(message);
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
      onDidReceiveNotificationResponse: (response) {
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
      unawaited(handler(message));
    }

    await _showLocalNotification(message);
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ?? data['title'] ?? 'Thông báo';
    final body = notification?.body ?? data['body'] ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final payload = jsonEncode(data);
    final id = DateTime.now().millisecondsSinceEpoch.remainder(1 << 31);

    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
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
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _handleOpenedRemoteMessage(RemoteMessage message) async {
    await NotificationStorage.persistFromRemoteMessage(message);
    NotificationNavigation.openFromRemoteMessage(message);
  }
}
