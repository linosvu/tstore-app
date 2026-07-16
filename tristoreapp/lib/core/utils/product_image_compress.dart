import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../services/api_client.dart';

/// Pre-shrink ảnh sản phẩm rồi upload lên POST /admin/upload.
///
/// Trả về URL server (ví dụ `/uploads/uuid.webp`) hoặc `null` nếu thất bại.
/// Client chỉ nén 1 lần để giảm bandwidth upload; server xử lý chất lượng
/// cuối cùng bằng sharp (WebP 80%).
Future<String?> uploadProductImageFromPath(
  String path,
  ApiClient api, {
  void Function(double progress)? onProgress,
}) async {
  if (path.isEmpty) return null;

  onProgress?.call(0);
  // Pre-shrink 1 lần — mục tiêu raw bytes ≤ 1MB để giảm thời gian upload.
  final Uint8List? bytes = await FlutterImageCompress.compressWithFile(
    path,
    minWidth: 1200,
    minHeight: 1200,
    quality: 78,
    format: CompressFormat.jpeg,
  );
  if (bytes == null || bytes.isEmpty) return null;

  final form = FormData.fromMap({
    'file': MultipartFile.fromBytes(
      bytes,
      filename: 'image.jpg',
      contentType: DioMediaType('image', 'jpeg'),
    ),
  });

  try {
    final res = await api.post<Map<String, dynamic>>(
      '/admin/upload',
      data: form,
      onSendProgress: (sent, total) {
        if (total > 0) {
          onProgress?.call((sent / total).clamp(0.0, 1.0));
        }
      },
    );
    onProgress?.call(1);
    return res.data?['url'] as String?;
  } on DioException {
    return null;
  }
}
