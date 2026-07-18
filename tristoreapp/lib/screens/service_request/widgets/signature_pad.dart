import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/utils/product_image_compress.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';

/// Chữ ký đơn giản: vẽ → PNG tạm → upload.
class SignaturePadSection extends StatefulWidget {
  const SignaturePadSection({
    super.key,
    required this.ticketId,
    required this.stage,
    required this.signer,
    required this.signatures,
    required this.onChanged,
    this.readOnly = false,
    this.title,
  });

  final String ticketId;
  final String stage;
  final String signer;
  final List<TicketSignaturePublic> signatures;
  final VoidCallback onChanged;
  final bool readOnly;
  final String? title;

  @override
  State<SignaturePadSection> createState() => _SignaturePadSectionState();
}

class _SignaturePadSectionState extends State<SignaturePadSection> {
  final _strokes = <List<Offset>>[];
  List<Offset> _current = [];
  final _repaintKey = GlobalKey();
  bool _busy = false;

  List<TicketSignaturePublic> get _existing => widget.signatures
      .where((s) => s.stage == widget.stage && s.signer == widget.signer)
      .toList();

  Future<void> _save() async {
    if (_busy || widget.readOnly) return;
    if (_strokes.isEmpty && _current.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        const SnackBar(content: Text('Vui lòng ký trước.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Không render được chữ ký');
      final image = await boundary.toImage(pixelRatio: 2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Xuất PNG thất bại');
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/sig_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      final api = context.read<AuthProvider>().api;
      final url = await uploadProductImageFromPath(path, api);
      if (url == null || url.isEmpty) {
        throw Exception('Upload chữ ký thất bại');
      }
      await context.read<ServiceRequestsProvider>().addSignature(
        widget.ticketId,
        {
          'stage': widget.stage,
          'signer': widget.signer,
          'imageUrl': url,
        },
      );
      _strokes.clear();
      _current = [];
      widget.onChanged();
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Đã lưu chữ ký.')),
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ??
        'Chữ ký ${widget.signer == 'customer' ? 'khách' : 'nhân viên'}';
    final existing = _existing;
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (existing.isNotEmpty)
            Text(
              'Đã có ${existing.length} chữ ký.',
              style: const TextStyle(color: Colors.green),
            ),
          if (!widget.readOnly) ...[
            const SizedBox(height: 8),
            Container(
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: GestureDetector(
                onPanStart: (d) {
                  setState(() {
                    _current = [d.localPosition];
                  });
                },
                onPanUpdate: (d) {
                  setState(() {
                    _current = [..._current, d.localPosition];
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    if (_current.isNotEmpty) _strokes.add(_current);
                    _current = [];
                  });
                },
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: CustomPaint(
                    painter: _SignaturePainter(
                      strokes: [
                        ..._strokes,
                        if (_current.isNotEmpty) _current,
                      ],
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _strokes.clear();
                            _current = [];
                          }),
                  child: const Text('Xoá'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Lưu chữ ký'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, 1.5, paint);
        }
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
