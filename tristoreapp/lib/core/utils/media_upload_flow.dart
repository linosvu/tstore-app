import 'dart:io';

import 'package:flutter/material.dart';

import '../widgets/app_messenger.dart';
import '../widgets/media_picker_sheet.dart';
import '../widgets/pending_media_tile.dart';
import 'media_upload.dart';

typedef PendingMediaEnqueue = void Function(PendingMediaUpload pending);
typedef PendingMediaDequeue = void Function(String id);

Future<bool> validateMediaPick({
  required BuildContext context,
  required MediaPickResult pick,
  required UploadConfig? config,
  required String tooLargeMessage,
  required String tooLongMessage,
}) async {
  if (!pick.isVideo || config == null) return true;
  final file = File(pick.path);
  if (await file.exists()) {
    final size = await file.length();
    if (size > config.maxVideoBytes) {
      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text(tooLargeMessage)),
        );
      }
      return false;
    }
  }
  final dur = await videoDurationSeconds(pick.path);
  if (dur != null && dur > config.maxVideoDurationSeconds) {
    if (context.mounted) {
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(tooLongMessage)),
      );
    }
    return false;
  }
  return true;
}

PendingMediaUpload enqueuePendingMedia({
  required MediaPickResult pick,
  String? scopeKey,
}) {
  return PendingMediaUpload(
    id: '${DateTime.now().microsecondsSinceEpoch}_${pick.path.hashCode}',
    localPath: pick.path,
    isVideo: pick.isVideo,
    scopeKey: scopeKey,
  );
}
