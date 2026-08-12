import 'package:flutter/material.dart';
import 'package:tstore/core/widgets/media_tile.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';

/// Thumbnail chữ ký (dùng chung SC / HTN) — nhãn + ảnh + phụ đề (vd. thời điểm ký).
class SignatureThumb extends StatelessWidget {
  const SignatureThumb({
    super.key,
    required this.label,
    required this.url,
    this.subtitle,
  });

  final String label;
  final String url;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MediaViewerPage(
                      items: [
                        MediaViewerItem(url: url, mediaType: 'image'),
                      ],
                      initialIndex: 0,
                    ),
                  ),
                );
              },
              child: Container(
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.network(
                  resolveMediaUrl(url),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.draw_outlined)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
