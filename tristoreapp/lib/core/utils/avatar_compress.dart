import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../services/api_client.dart';

/// Pre-shrink ảnh avatar rồi upload lên POST /admin/upload.
///
/// Trả về URL server (ví dụ `/uploads/uuid.webp`) hoặc `null` nếu thất bại.
Future<String?> uploadAvatarFromPath(
  String path,
  ApiClient api,
) async {
  if (path.isEmpty) return null;

  final Uint8List? bytes = await FlutterImageCompress.compressWithFile(
    path,
    minWidth: 512,
    minHeight: 512,
    quality: 80,
    format: CompressFormat.jpeg,
  );
  if (bytes == null || bytes.isEmpty) return null;

  final form = FormData.fromMap({
    'file': MultipartFile.fromBytes(
      bytes,
      filename: 'avatar.jpg',
      contentType: DioMediaType('image', 'jpeg'),
    ),
  });

  try {
    final res = await api.post<Map<String, dynamic>>(
      '/admin/upload',
      data: form,
    );
    return res.data?['url'] as String?;
  } on DioException {
    return null;
  }
}
