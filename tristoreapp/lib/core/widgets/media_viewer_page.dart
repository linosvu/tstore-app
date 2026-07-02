import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:video_player/video_player.dart';

import '../localization/app_localizations.dart';
import '../utils/media_save_service.dart';
import '../utils/media_video_cache.dart';
import 'media_tile.dart';
import 'media_viewer_controls.dart';

class MediaViewerItem {
  const MediaViewerItem({
    required this.url,
    this.mediaType,
  });

  final String url;
  final String? mediaType;
}

class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<MediaViewerItem> items;
  final int initialIndex;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late final PageController _pageController;
  late int _index;
  VideoPlayerController? _videoController;
  int _videoGeneration = 0;
  bool _videoLoading = false;
  bool _videoError = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _initVideoForIndex(_index);
  }

  @override
  void dispose() {
    _disposeVideo();
    _pageController.dispose();
    super.dispose();
  }

  void _onVideoStateChanged() {
    if (mounted) setState(() {});
  }

  void _disposeVideo() {
    _videoController?.removeListener(_onVideoStateChanged);
    _videoController?.dispose();
    _videoController = null;
  }

  void _goToPage(int target) {
    if (target < 0 ||
        target >= widget.items.length ||
        target == _index ||
        !_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _goPrevious() => _goToPage(_index - 1);

  void _goNext() => _goToPage(_index + 1);

  Future<void> _downloadCurrent(BuildContext context) async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context);
    final item = widget.items[_index];
    setState(() => _saving = true);
    try {
      await MediaSaveService.saveToGallery(
        url: item.url,
        mediaType: item.mediaType,
      );
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.mediaViewerDownloadSuccess)),
      );
    } on MediaSaveException catch (e) {
      if (!mounted) return;
      final msg = switch (e.failure) {
        MediaSaveFailure.permissionDenied =>
          l10n.mediaViewerDownloadPermissionDenied,
        _ => l10n.mediaViewerDownloadFailed,
      };
      AppMessenger.showSnackBar(context, SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.mediaViewerDownloadFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _initVideoForIndex(int i) async {
    _disposeVideo();
    final item = widget.items[i];
    if (!isVideoMediaType(item.mediaType, item.url)) return;

    final gen = ++_videoGeneration;
    if (mounted) {
      setState(() {
        _videoLoading = true;
        _videoError = false;
      });
    }

    try {
      final file = await getCachedVideoFile(item.url);
      if (!mounted || _index != i || gen != _videoGeneration) return;

      final controller = VideoPlayerController.file(file);
      _videoController = controller;
      controller.addListener(_onVideoStateChanged);
      await controller.initialize();
      if (!mounted || _index != i || gen != _videoGeneration) {
        controller.removeListener(_onVideoStateChanged);
        controller.dispose();
        _videoController = null;
        return;
      }
      setState(() {
        _videoLoading = false;
        _videoError = false;
      });
    } catch (e, st) {
      debugPrint('[VideoPlayer] ERROR: $e\n$st');
      if (!mounted || _index != i || gen != _videoGeneration) return;
      setState(() {
        _videoLoading = false;
        _videoError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    final mq = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final canPrev = _index > 0;
    final canNext = _index < n - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: n,
            onPageChanged: (i) {
              setState(() => _index = i);
              _initVideoForIndex(i);
            },
            itemBuilder: (ctx, i) {
              final item = widget.items[i];
              if (isVideoMediaType(item.mediaType, item.url)) {
                return _buildVideo(i);
              }
              return InteractiveViewer(
                minScale: 0.85,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: resolveMediaUrl(item.url),
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: mq.padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                MediaViewerCounterBadge(current: _index + 1, total: n),
                const Spacer(),
                MediaViewerDownloadButton(
                  busy: _saving,
                  onPressed: () => _downloadCurrent(context),
                ),
                const SizedBox(width: 8),
                const MediaViewerCloseButton(),
              ],
            ),
          ),
          if (n > 1)
            Positioned(
              left: 8,
              top: 0,
              bottom: mq.padding.bottom + 16,
              child: Center(
                child: MediaViewerNavButton(
                  icon: Icons.chevron_left_rounded,
                  label: l10n.mediaViewerPrevious,
                  enabled: canPrev,
                  onTap: _goPrevious,
                ),
              ),
            ),
          if (n > 1)
            Positioned(
              right: 8,
              top: 0,
              bottom: mq.padding.bottom + 16,
              child: Center(
                child: MediaViewerNavButton(
                  icon: Icons.chevron_right_rounded,
                  label: l10n.mediaViewerNext,
                  enabled: canNext,
                  onTap: _goNext,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideo(int i) {
    if (_index != i) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_videoError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Không thể phát video',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _initVideoForIndex(i),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Thử lại',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final c = _videoController;
    if (_videoLoading || c == null || !c.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio,
        child: GestureDetector(
          onTap: () {
            if (c.value.isPlaying) {
              c.pause();
            } else {
              c.play();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(c),
              AnimatedOpacity(
                opacity: c.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
