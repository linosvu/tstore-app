import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_localizations.dart';
import '../utils/media_upload.dart';

enum MediaPickKind {
  cameraPhoto,
  cameraVideo,
  galleryPhoto,
  galleryVideo,
}

class MediaPickResult {
  const MediaPickResult({
    required this.path,
    required this.isVideo,
  });

  final String path;
  final bool isVideo;
}

Future<MediaPickResult?> showMediaPickerSheet(
  BuildContext context, {
  UploadConfig? config,
}) async {
  final l10n = AppLocalizations.of(context);
  final kind = await showModalBottomSheet<MediaPickKind>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.mediaPickTitle,
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              if (config != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.mediaLimitsHint(
                    config.maxImageBytes,
                    config.maxVideoBytes,
                    config.maxVideoDurationSeconds,
                  ),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.productsImageFromCamera),
                onTap: () => Navigator.pop(ctx, MediaPickKind.cameraPhoto),
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: Text(l10n.mediaRecordVideo),
                onTap: () => Navigator.pop(ctx, MediaPickKind.cameraVideo),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.productsImageFromGallery),
                onTap: () => Navigator.pop(ctx, MediaPickKind.galleryPhoto),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: Text(l10n.mediaPickVideoFromGallery),
                onTap: () => Navigator.pop(ctx, MediaPickKind.galleryVideo),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (kind == null) return null;

  final picker = ImagePicker();
  switch (kind) {
    case MediaPickKind.cameraPhoto:
      final x = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 92,
      );
      if (x == null) return null;
      return MediaPickResult(path: x.path, isVideo: false);
    case MediaPickKind.galleryPhoto:
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
      );
      if (x == null) return null;
      return MediaPickResult(path: x.path, isVideo: false);
    case MediaPickKind.cameraVideo:
      final x = await picker.pickVideo(source: ImageSource.camera);
      if (x == null) return null;
      return MediaPickResult(path: x.path, isVideo: true);
    case MediaPickKind.galleryVideo:
      final x = await picker.pickVideo(source: ImageSource.gallery);
      if (x == null) return null;
      return MediaPickResult(path: x.path, isVideo: true);
  }
}
