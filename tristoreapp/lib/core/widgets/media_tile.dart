import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';

String resolveMediaUrl(String raw) {
  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    // Fix legacy R2 URLs where publicBaseUrl was saved without the bucket name.
    // Correct format: https://<hash>.r2.dev/<bucket>/media/<uuid>
    // Legacy format:  https://<hash>.r2.dev/media/<uuid>  (missing bucket)
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.host.endsWith('.r2.dev') &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == 'media') {
      // Path starts with /media/ — missing the bucket segment.
      // Derive bucket from the first path segment of a known-good API URL or
      // fall back to 'tstore' (the configured bucket for this deployment).
      const bucket = 'tstore';
      return raw.replaceFirst('/media/', '/$bucket/media/');
    }
    return raw;
  }
  if (raw.startsWith('/')) {
    return ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '') + raw;
  }
  return raw;
}

bool isVideoMediaType(String? mediaType, String url) {
  if (mediaType == 'video') return true;
  final lower = url.toLowerCase();
  return lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.webm') ||
      lower.endsWith('.avi');
}

class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.url,
    this.mediaType,
    this.width = 72,
    this.height = 72,
    this.fit = BoxFit.cover,
    this.onTap,
  });

  final String url;
  final String? mediaType;
  final double width;
  final double height;
  final BoxFit fit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isVideo = isVideoMediaType(mediaType, url);
    final child = isVideo
        ? _videoThumb(context)
        : _imageThumb(context);

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: child,
    );
  }

  Widget _imageThumb(BuildContext context) {
    if (url.startsWith('data:image')) {
      final i = url.indexOf(',');
      if (i > 0) {
        try {
          final bytes = base64Decode(url.substring(i + 1));
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => _errorBox(context),
            ),
          );
        } catch (_) {
          return _errorBox(context);
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: resolveMediaUrl(url),
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _errorBox(context),
      ),
    );
  }

  Widget _videoThumb(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: width,
        height: height,
        color: scheme.surfaceContainerHighest,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.videocam_outlined,
              size: width * 0.35,
              color: scheme.onSurfaceVariant,
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}
