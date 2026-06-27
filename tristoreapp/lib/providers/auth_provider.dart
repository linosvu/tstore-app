import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/api_config.dart';
import '../core/services/api_client.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/token_storage.dart';
import '../models/auth_user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required ApiClient api}) : _api = api {
    _api.debugLogBaseUrl();
  }

  final ApiClient _api;
  StreamSubscription<String>? _fcmTokenRefreshSub;

  /// Gọi API đã gắn token (vd. `/admin/products`).
  ApiClient get api => _api;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  String? _lastError;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  String? get lastError => _lastError;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;

  /// Gọi khi khởi động: có token thì xác thực `/auth/me`.
  Future<void> tryRestore() async {
    _lastError = null;
    final token = await TokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      notifyListeners();
      return;
    }
    try {
      final res = await _api.get<Map<String, dynamic>>('/auth/me');
      final data = res.data;
      if (data == null) {
        await _clearSession();
        return;
      }
      _user = AuthUser.fromJson(data);
      _status = AuthStatus.authenticated;
      notifyListeners();
      unawaited(_registerFcmToken());
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _clearSession();
      } else {
        _lastError = _messageFromDio(e);
        _status = AuthStatus.unauthenticated;
        _user = null;
        await TokenStorage.clear();
        notifyListeners();
      }
    } catch (e) {
      _lastError = e.toString();
      _status = AuthStatus.unauthenticated;
      _user = null;
      await TokenStorage.clear();
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _lastError = null;
    notifyListeners();
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim(), 'password': password},
      );
      final data = res.data;
      if (data == null) {
        _lastError = 'Phản hồi không hợp lệ từ máy chủ.';
        notifyListeners();
        return;
      }
      final token = data['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        _lastError = 'Thiếu token đăng nhập.';
        notifyListeners();
        return;
      }
      await TokenStorage.writeAccessToken(token);
      final userJson = data['user'] as Map<String, dynamic>?;
      if (userJson == null) {
        await tryRestore();
        return;
      }
      _user = AuthUser.fromJson(userJson);
      _status = AuthStatus.authenticated;
      notifyListeners();
      unawaited(_registerFcmToken());
    } on DioException catch (e) {
      _lastError = _messageFromDio(e);
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _unregisterFcmToken();
    await _clearSession();
  }

  Future<void> _registerFcmToken() async {
    try {
      await _fcmTokenRefreshSub?.cancel();
      _fcmTokenRefreshSub = null;

      final token = await PushNotificationService.instance.getToken();
      if (token == null) return;
      final platform = _deviceTokenPlatform();
      await _api.post<void>(
        '/auth/device-token',
        data: {'token': token, 'platform': platform},
      );
      _fcmTokenRefreshSub = PushNotificationService.instance.onTokenRefresh
          .listen((newToken) async {
        try {
          await _api.post<void>(
            '/auth/device-token',
            data: {'token': newToken, 'platform': platform},
          );
        } catch (e) {
          debugPrint('[FCM] token refresh register failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[FCM] register token failed: $e');
      // Non-critical — không block login
    }
  }

  String _deviceTokenPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return defaultTargetPlatform.name;
    }
  }

  Future<void> _unregisterFcmToken() async {
    await _fcmTokenRefreshSub?.cancel();
    _fcmTokenRefreshSub = null;
    try {
      final token = await PushNotificationService.instance.getToken();
      if (token == null) return;
      await _api.delete<void>(
        '/auth/device-token',
        data: {'token': token},
      );
    } catch (_) {
      // Non-critical
    }
  }

  /// Làm mới profile từ `/auth/me` (kéo để làm mới, sau khi admin đổi ảnh trên web, …).
  Future<void> refreshMe() async {
    if (!isAuthenticated) return;
    try {
      final res = await _api.get<Map<String, dynamic>>('/auth/me');
      final data = res.data;
      if (data != null) {
        _user = AuthUser.fromJson(data);
        notifyListeners();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _clearSession();
      }
    }
  }

  /// `POST /auth/change-password` — đổi mật khẩu. Trả `null` nếu thành công.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.post<Map<String, dynamic>>(
        '/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      return null;
    } on DioException catch (e) {
      return _messageFromDio(e);
    } catch (e) {
      return e.toString();
    }
  }

  /// `PATCH /auth/profile` — gửi ít nhất một trường. Trả `null` nếu thành công.
  Future<String?> patchProfile({
    String? fullName,
    String? email,
    String? avatarUrl,
    bool clearAvatar = false,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) {
      final t = fullName.trim();
      if (t.isEmpty) return 'Họ tên không được để trống.';
      body['fullName'] = t;
    }
    if (email != null) {
      final t = email.trim().toLowerCase();
      if (t.isEmpty) return 'Email không được để trống.';
      if (!t.contains('@')) return 'Email không hợp lệ.';
      body['email'] = t;
    }
    if (clearAvatar) {
      body['avatarUrl'] = '';
    } else if (avatarUrl != null) {
      body['avatarUrl'] = avatarUrl;
    }
    if (body.isEmpty) return 'Không có thay đổi.';
    try {
      final res = await _api.patch<Map<String, dynamic>>(
        '/auth/profile',
        data: body,
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final data = res.data;
      if (data != null) {
        _user = AuthUser.fromJson(data);
        notifyListeners();
      }
      return null;
    } on DioException catch (e) {
      return _messageFromDio(e);
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> _clearSession() async {
    await TokenStorage.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      if (m is String) return m;
      if (m is List && m.isNotEmpty) return m.first.toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      const base =
          'Không kết nối được máy chủ. Kiểm tra PC và điện thoại cùng Wi‑Fi, firewall cổng 3000, và IP đúng (không dùng 192.168.1.1 nếu đó là router).';
      if (kDebugMode) {
        return '$base\nAPI: ${ApiConfig.baseUrl}\n${e.message ?? e.toString()}';
      }
      return '$base Đang dùng: ${ApiConfig.baseUrl}';
    }
    return 'Yêu cầu thất bại (${e.response?.statusCode ?? '?'})';
  }
}
