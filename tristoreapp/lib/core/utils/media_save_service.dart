import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../widgets/media_tile.dart';
import 'media_video_cache.dart';

enum MediaSaveFailure {
  permissionDenied,
  downloadFailed,
  saveFailed,
}

class MediaSaveException implements Exception {
  const MediaSaveException(this.failure, [this.cause]);

  final MediaSaveFailure failure;
  final Object? cause;

  @override
  String toString() => 'MediaSaveException($failure, $cause)';
}

/// Lưu ảnh/video vào thư viện thiết bị — ưu tiên file đã cache để không tải lại.
class MediaSaveService {
  const MediaSaveService._();

  static Future<void> saveToGallery({
    required String url,
    String? mediaType,
    String? baseUrl,
  }) async {
    final isVideo = isVideoMediaType(mediaType, url);
    await _ensureGalleryAccess();

    final file = await _resolveLocalFile(
      url,
      isVideo: isVideo,
      baseUrl: baseUrl,
    );

    try {
      if (isVideo) {
        await Gal.putVideo(file.path);
      } else {
        await Gal.putImage(file.path);
      }
    } catch (e, st) {
      debugPrint('[MediaSave] put failed: $e\n$st');
      throw MediaSaveException(MediaSaveFailure.saveFailed, e);
    }
  }

  static Future<void> _ensureGalleryAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return;
    final granted = await Gal.requestAccess(toAlbum: true);
    if (!granted) {
      throw const MediaSaveException(MediaSaveFailure.permissionDenied);
    }
  }

  static Future<File> _resolveLocalFile(
    String url, {
    required bool isVideo,
    String? baseUrl,
  }) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw const MediaSaveException(MediaSaveFailure.downloadFailed);
    }

    if (trimmed.startsWith('data:image')) {
      return _dataUrlToTempFile(trimmed, isVideo: false);
    }

    if (trimmed.startsWith('file://')) {
      final f = File(Uri.parse(trimmed).path);
      if (await f.exists()) return f;
      throw const MediaSaveException(MediaSaveFailure.downloadFailed);
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      final local = File(trimmed);
      if (await local.exists()) return local;
    }

    final resolved = _normalizeUrl(trimmed, baseUrl: baseUrl);
    try {
      if (isVideo) {
        return getCachedVideoFile(resolved);
      }
      return DefaultCacheManager().getSingleFile(resolved);
    } catch (e, st) {
      debugPrint('[MediaSave] resolve failed: $e\n$st');
      throw MediaSaveException(MediaSaveFailure.downloadFailed, e);
    }
  }

  static Future<File> _dataUrlToTempFile(
    String dataUrl, {
    required bool isVideo,
  }) async {
    final i = dataUrl.indexOf(',');
    if (i <= 0) {
      throw const MediaSaveException(MediaSaveFailure.downloadFailed);
    }
    try {
      final bytes = base64Decode(dataUrl.substring(i + 1));
      final dir = await getTemporaryDirectory();
      final ext = isVideo ? '.mp4' : '.jpg';
      final file = File(
        p.join(dir.path, 'media_save_${DateTime.now().millisecondsSinceEpoch}$ext'),
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e, st) {
      debugPrint('[MediaSave] data URL decode failed: $e\n$st');
      throw MediaSaveException(MediaSaveFailure.downloadFailed, e);
    }
  }

  static String _normalizeUrl(String url, {String? baseUrl}) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/') && baseUrl != null && baseUrl.trim().isNotEmpty) {
      return baseUrl.replaceAll(RegExp(r'/$'), '') + url;
    }
    return resolveMediaUrl(url);
  }
}
