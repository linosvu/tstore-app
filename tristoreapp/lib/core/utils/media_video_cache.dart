import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../widgets/media_tile.dart';

final _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
    sendTimeout: const Duration(seconds: 30),
  ),
);

String _cacheKey(String url) {
  final hash = md5.convert(url.codeUnits).toString();
  final ext = url.contains('.mp4')
      ? '.mp4'
      : url.contains('.mov')
          ? '.mov'
          : url.contains('.webm')
              ? '.webm'
              : '.mp4';
  return 'vid_$hash$ext';
}

Future<File> getCachedVideoFile(String url) async {
  final resolvedUrl = resolveMediaUrl(url);
  final dir = await getApplicationCacheDirectory();
  final cacheFile = File('${dir.path}/${_cacheKey(resolvedUrl)}');

  if (await cacheFile.exists()) {
    final size = await cacheFile.length();
    if (size > 1024) {
      debugPrint('[VideoCache] HIT $resolvedUrl (${(size / 1024).round()} KB)');
      return cacheFile;
    }
    await cacheFile.delete();
  }

  debugPrint('[VideoCache] DOWNLOAD $resolvedUrl');
  final tmpFile = File('${cacheFile.path}.tmp');
  try {
    await _dio.download(
      resolvedUrl,
      tmpFile.path,
      onReceiveProgress: (received, total) {
        if (total > 0 && received % (1024 * 512) < 8192) {
          debugPrint(
              '[VideoCache] ${(received / 1024).round()} / ${(total / 1024).round()} KB');
        }
      },
    );
    await tmpFile.rename(cacheFile.path);
    final size = await cacheFile.length();
    debugPrint('[VideoCache] SAVED ${(size / 1024).round()} KB → ${cacheFile.path}');
    return cacheFile;
  } catch (e) {
    debugPrint('[VideoCache] ERROR: $e');
    if (await tmpFile.exists()) await tmpFile.delete();
    rethrow;
  }
}
