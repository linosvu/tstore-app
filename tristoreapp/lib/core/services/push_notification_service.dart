import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

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

  static Future<void>? _firebaseReadyFuture;

  /// Khởi tạo Firebase + push (gọi trước khi đăng ký token với server).
  static Future<void> ensureFirebaseReady() {
    return _firebaseReadyFuture ??= _bootstrapFirebase();
  }

  static Future<void> _bootstrapFirebase() async {
    try {
      await Firebase.initializeApp();
      await instance.init();
    } catch (e, stack) {
      debugPrint('[Firebase] init failed: $e\n$stack');
      rethrow;
    }
  }

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

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');

    if (!kIsWeb && Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

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
      if (!kIsWeb && Platform.isIOS) {
        await _waitForApnsToken();
      }
      final token = await _messaging.getToken();
      debugPrint(
        '[FCM] getToken: ${token != null ? '${token.substring(0, 12)}…' : 'null'}',
      );
      return token;
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  /// Callback khi token thay đổi (app cần đăng ký lại với server).
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final apns = await _messaging.getAPNSToken();
      if (apns != null) {
        debugPrint('[FCM] APNs token ready');
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('[FCM] APNs token still null after wait');
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
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
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: 'Thông báo đơn hàng, chuẩn bị, giao hàng',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
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
