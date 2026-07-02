import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tstore/core/utils/media_save_service.dart';
import 'package:tstore/core/widgets/app_messenger.dart';

import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/widgets/media_viewer_controls.dart';

/// Ảnh sản phẩm từ URL http(s), URL tương đối (/uploads/...) hoặc data URL.
///
/// - http(s) và URL tương đối → [CachedNetworkImage] (cache disk, không tải lại giữa session).
/// - data:image → [Image.memory] (backward compat với ảnh cũ còn trong DB).
class ProductImageUrl extends StatelessWidget {
  const ProductImageUrl({
    super.key,
    required this.url,
    required this.fit,
    this.width,
    this.height,
    this.baseUrl,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// URL gốc của API (dùng để resolve URL tương đối như `/uploads/...`).
  /// Nếu null thì URL tương đối sẽ không hiển thị được.
  final String? baseUrl;

  @override
  Widget build(BuildContext context) {
    // URL tuyệt đối hoặc tương đối → dùng CachedNetworkImage
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return _cachedImage(url);
    }
    if (url.startsWith('/') && baseUrl != null) {
      final fullUrl = baseUrl!.replaceAll(RegExp(r'/$'), '') + url;
      return _cachedImage(fullUrl);
    }

    // data:image — backward compat với ảnh cũ trong DB
    if (url.startsWith('data:image')) {
      final i = url.indexOf(',');
      if (i > 0) {
        try {
          final bytes = base64Decode(url.substring(i + 1));
          return Image.memory(
            Uint8List.fromList(bytes),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _brokenBox(width, height),
          );
        } catch (_) {}
      }
    }

    return _brokenBox(width, height);
  }

  Widget _cachedImage(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width?.toInt(),
      memCacheHeight: height?.toInt(),
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
      ),
      errorWidget: (_, __, ___) => _brokenBox(width, height),
    );
  }

  Widget _brokenBox(double? w, double? h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade300,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

class ProductImageGalleryDialog extends StatefulWidget {
  const ProductImageGalleryDialog({
    super.key,
    required this.urls,
    required this.initialIndex,
    this.baseUrl,
  });

  final List<String> urls;
  final int initialIndex;
  final String? baseUrl;

  @override
  State<ProductImageGalleryDialog> createState() => _ProductImageGalleryDialogState();
}

class _ProductImageGalleryDialogState extends State<ProductImageGalleryDialog> {
  late final PageController _pageController;
  late int _index;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final last = widget.urls.length - 1;
    final safe = widget.initialIndex.clamp(0, last < 0 ? 0 : last);
    _index = safe;
    _pageController = PageController(initialPage: safe);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int target) {
    if (target < 0 ||
        target >= widget.urls.length ||
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
    setState(() => _saving = true);
    try {
      await MediaSaveService.saveToGallery(
        url: widget.urls[_index],
        baseUrl: widget.baseUrl,
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
    } catch (_) {
      if (!mounted) return;
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text(l10n.mediaViewerDownloadFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context);
    final n = widget.urls.length;
    final canPrev = _index > 0;
    final canNext = _index < n - 1;
    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (ctx, i) {
              return LayoutBuilder(
                builder: (ctx, c) {
                  return Center(
                    child: InteractiveViewer(
                      minScale: 0.6,
                      maxScale: 4,
                      boundaryMargin: const EdgeInsets.all(48),
                      child: ProductImageUrl(
                        url: widget.urls[i],
                        width: c.maxWidth,
                        height: c.maxHeight,
                        fit: BoxFit.contain,
                        baseUrl: widget.baseUrl,
                      ),
                    ),
                  );
                },
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
}
