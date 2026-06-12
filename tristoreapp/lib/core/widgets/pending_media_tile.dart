import 'dart:io';

import 'package:flutter/material.dart';

/// Mục media đang upload — hiển thị preview local + loading.
class PendingMediaUpload {
  PendingMediaUpload({
    required this.id,
    required this.localPath,
    required this.isVideo,
    this.scopeKey,
  });

  final String id;
  final String localPath;
  final bool isVideo;
  /// Phân vùng theo tab/section (vd. delivery: received / installation).
  final String? scopeKey;
}

class LocalMediaPreviewTile extends StatelessWidget {
  const LocalMediaPreviewTile({
    super.key,
    required this.localPath,
    required this.isVideo,
    this.width = 72,
    this.height = 72,
    this.loading = true,
    this.error = false,
  });

  final String localPath;
  final bool isVideo;
  final double width;
  final double height;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!isVideo)
              Image.file(
                File(localPath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: Icon(
                  Icons.videocam_outlined,
                  size: width * 0.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            if (loading)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.42),
                child: const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (error)
              ColoredBox(
                color: Colors.red.withValues(alpha: 0.35),
                child: const Center(
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
