import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';

/// Thông báo lỗi ngắn gọn từ [DioException] (không dump cả đoạn validateStatus).
String dioErrorMessage(DioException e) {
  final code = e.response?.statusCode;
  if (code == 401) {
    return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.';
  }
  if (code == 403) {
    return 'Bạn không có quyền thực hiện thao tác này.';
  }
  if (code == 404) {
    return 'Không tìm thấy dữ liệu trên máy chủ.';
  }

  final data = e.response?.data;
  if (data is Map && data['message'] != null) {
    final m = data['message'];
    if (m is String && m.isNotEmpty) return m;
    if (m is List && m.isNotEmpty) return m.first.toString();
  }

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    if (kDebugMode) {
      return 'Không kết nối được máy chủ (${ApiConfig.baseUrl}).\n${e.message ?? ''}';
    }
    return 'Không kết nối được máy chủ. Kiểm tra mạng và thử lại.';
  }

  if (code != null) {
    return 'Yêu cầu thất bại (mã $code).';
  }
  return e.message ?? 'Lỗi không xác định';
}

bool isDioUnauthorized(DioException e) => e.response?.statusCode == 401;
