import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'token_storage.dart';

/// HTTP client gắn Bearer token; 401 phiên hết hạn → [onUnauthorized].
class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/json'},
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final t = await TokenStorage.readAccessToken();
          if (t != null && t.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $t';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          if (_shouldHandleUnauthorized(e)) {
            _notifyUnauthorizedOnce();
          }
          handler.next(e);
        },
      ),
    );
  }

  /// Gán sau khi có [AuthProvider] (tránh vòng phụ thuộc).
  void Function()? onUnauthorized;
  late final Dio _dio;
  bool _handlingUnauthorized = false;

  Dio get dio => _dio;

  /// Cho phép gọi lại sau khi user đăng nhập lại.
  void resetUnauthorizedGuard() {
    _handlingUnauthorized = false;
  }

  bool _shouldHandleUnauthorized(DioException e) {
    if (e.response?.statusCode != 401) return false;
    final path = e.requestOptions.path;
    // Sai mật khẩu / auth công khai — không coi là hết phiên.
    if (_isPublicAuthPath(path)) return false;
    final auth = e.requestOptions.headers['Authorization'];
    final hadBearer =
        auth is String && auth.startsWith('Bearer ') && auth.length > 7;
    return hadBearer;
  }

  bool _isPublicAuthPath(String path) {
    final p = path.toLowerCase();
    return p.contains('/auth/login') ||
        p.endsWith('/auth/login') ||
        p.contains('/auth/register');
  }

  void _notifyUnauthorizedOnce() {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    try {
      onUnauthorized?.call();
    } catch (err, st) {
      debugPrint('[ApiClient] onUnauthorized failed: $err\n$st');
      _handlingUnauthorized = false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Options? options,
    void Function(int sent, int total)? onSendProgress,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      options: options,
      onSendProgress: onSendProgress,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.patch<T>(path, data: data, options: options);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.put<T>(path, data: data, options: options);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Options? options,
  }) {
    return _dio.delete<T>(path, data: data, options: options);
  }

  void debugLogBaseUrl() {
    debugPrint('TStore API: ${ApiConfig.baseUrl}');
  }
}
