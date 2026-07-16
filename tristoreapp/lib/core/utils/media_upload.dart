import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../services/api_client.dart';

class UploadConfig {
  const UploadConfig({
    required this.storageEnabled,
    required this.maxImageBytes,
    required this.maxVideoBytes,
    required this.maxVideoDurationSeconds,
  });

  final bool storageEnabled;
  final int maxImageBytes;
  final int maxVideoBytes;
  final int maxVideoDurationSeconds;

  factory UploadConfig.fromJson(Map<String, dynamic> json) {
    return UploadConfig(
      storageEnabled: json['storageEnabled'] as bool? ?? false,
      maxImageBytes: (json['maxImageBytes'] as num?)?.toInt() ?? 5 * 1024 * 1024,
      maxVideoBytes:
          (json['maxVideoBytes'] as num?)?.toInt() ?? 50 * 1024 * 1024,
      maxVideoDurationSeconds:
          (json['maxVideoDurationSeconds'] as num?)?.toInt() ?? 120,
    );
  }
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.url,
    required this.mediaType,
    required this.mimeType,
  });

  final String url;
  final String mediaType;
  final String mimeType;
}

Future<UploadConfig?> fetchUploadConfig(ApiClient api) async {
  try {
    final res = await api.get<Map<String, dynamic>>('/admin/upload/config');
    final data = res.data;
    if (data == null) return null;
    return UploadConfig.fromJson(data);
  } on DioException {
    return null;
  }
}

String _guessVideoMime(String path) {
  final ext = p.extension(path).toLowerCase();
  switch (ext) {
    case '.mov':
      return 'video/quicktime';
    case '.webm':
      return 'video/webm';
    case '.avi':
      return 'video/x-msvideo';
    default:
      return 'video/mp4';
  }
}

Future<int?> videoDurationSeconds(String path) async {
  final controller = VideoPlayerController.file(File(path));
  try {
    await controller.initialize();
    final d = controller.value.duration;
    if (d.inMilliseconds <= 0) return null;
    return d.inSeconds;
  } catch (_) {
    return null;
  } finally {
    await controller.dispose();
  }
}

Future<MediaUploadResult?> uploadImageFromPath(
  String path,
  ApiClient api, {
  void Function(double progress)? onProgress,
}) async {
  if (path.isEmpty) return null;

  onProgress?.call(0);
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
    final data = res.data;
    if (data == null) return null;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) return null;
    return MediaUploadResult(
      url: url,
      mediaType: data['mediaType'] as String? ?? 'image',
      mimeType: data['mimeType'] as String? ?? 'image/webp',
    );
  } on DioException {
    return null;
  }
}

Future<MediaUploadResult?> uploadVideoFromPath(
  String path,
  ApiClient api, {
  void Function(double progress)? onProgress,
}) async {
  if (path.isEmpty) return null;
  final file = File(path);
  if (!await file.exists()) return null;

  onProgress?.call(0);
  final bytes = await file.readAsBytes();
  if (bytes.isEmpty) return null;

  final mime = _guessVideoMime(path);
  final filename = p.basename(path);

  final form = FormData.fromMap({
    'file': MultipartFile.fromBytes(
      bytes,
      filename: filename,
      contentType: DioMediaType.parse(mime),
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
    final data = res.data;
    if (data == null) return null;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) return null;
    return MediaUploadResult(
      url: url,
      mediaType: data['mediaType'] as String? ?? 'video',
      mimeType: data['mimeType'] as String? ?? mime,
    );
  } on DioException {
    return null;
  }
}
