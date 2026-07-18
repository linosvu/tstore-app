import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../localization/app_localizations.dart';
import '../utils/media_upload.dart';
import 'app_messenger.dart';

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

bool _looksLikeVideoPath(String path) {
  final ext = p.extension(path).toLowerCase();
  return const {
    '.mp4',
    '.mov',
    '.m4v',
    '.avi',
    '.mkv',
    '.webm',
    '.3gp',
  }.contains(ext);
}

/// Chọn media: camera = 1 file; thư viện ảnh/video = nhiều file.
Future<List<MediaPickResult>?> showMediaPickerSheet(
  BuildContext context, {
  UploadConfig? config,
  bool allowVideo = true,
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
                  allowVideo
                      ? l10n.mediaLimitsHint(
                          config.maxImageBytes,
                          config.maxVideoBytes,
                          config.maxVideoDurationSeconds,
                        )
                      : l10n.mediaImageLimitHint(config.maxImageBytes),
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
              if (allowVideo)
                ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: Text(l10n.mediaRecordVideo),
                  onTap: () => Navigator.pop(ctx, MediaPickKind.cameraVideo),
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.productsImageFromGallery),
                subtitle: const Text('Có thể chọn nhiều ảnh'),
                onTap: () => Navigator.pop(ctx, MediaPickKind.galleryPhoto),
              ),
              if (allowVideo)
                ListTile(
                  leading: const Icon(Icons.video_library_outlined),
                  title: Text(l10n.mediaPickVideoFromGallery),
                  subtitle: const Text('Có thể chọn nhiều video'),
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
  final maxVideoDuration = config != null
      ? Duration(seconds: config.maxVideoDurationSeconds)
      : null;

  try {
    switch (kind) {
      case MediaPickKind.cameraPhoto:
        final x = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 92,
        );
        if (x == null) return null;
        return [MediaPickResult(path: x.path, isVideo: false)];
      case MediaPickKind.galleryPhoto:
        final xs = await picker.pickMultiImage(imageQuality: 92);
        if (xs.isEmpty) return null;
        return [
          for (final x in xs) MediaPickResult(path: x.path, isVideo: false),
        ];
      case MediaPickKind.cameraVideo:
        final x = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: maxVideoDuration,
        );
        if (x == null) return null;
        return [MediaPickResult(path: x.path, isVideo: true)];
      case MediaPickKind.galleryVideo:
        final xs = await picker.pickMultiVideo(maxDuration: maxVideoDuration);
        if (xs.isEmpty) return null;
        return [
          for (final x in xs)
            MediaPickResult(
              path: x.path,
              isVideo: _looksLikeVideoPath(x.path),
            ),
        ];
    }
  } on PlatformException catch (e) {
    if (context.mounted) {
      final msg = e.code == 'camera_access_denied' ||
              e.code == 'microphone_access_denied' ||
              e.code == 'photo_access_denied'
          ? 'Cần cấp quyền Camera và Micro trên iOS để quay video (Cài đặt → TStore).'
          : 'Không mở được camera/video: ${e.message ?? e.code}';
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    }
    return null;
  }
}
