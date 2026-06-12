import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
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
            top: mq.padding.top + 4,
            right: 4,
            child: IconButton(
              style: IconButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white24,
              ),
              icon: const Icon(Icons.close_rounded, size: 26),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: mq.padding.bottom + 20,
              left: 16,
              right: 16,
              child: Text(
                '${_index + 1} / ${widget.urls.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
