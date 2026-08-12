import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/core/widgets/media_tile.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/widgets/ui/section_card.dart';

/// Thông tin YC gốc (khoá) hiển thị trên phiếu con.
class LockedRequestInfoCard extends StatefulWidget {
  const LockedRequestInfoCard({
    super.key,
    required this.request,
    this.onEdit,
    this.appointmentDate,
    this.appointmentSlot,
  });

  final ServiceRequestBrief request;
  final VoidCallback? onEdit;
  final String? appointmentDate;
  final String? appointmentSlot;

  @override
  State<LockedRequestInfoCard> createState() => _LockedRequestInfoCardState();
}

class _LockedRequestInfoCardState extends State<LockedRequestInfoCard> {
  bool _showBuyer = false;

  ServiceRequestBrief get request => widget.request;

  bool get _hasBuyerInfo {
    final name = (request.buyerName ?? '').trim();
    final phone = (request.buyerPhone ?? '').trim();
    final address = (request.buyerAddress ?? '').trim();
    return name.isNotEmpty || phone.isNotEmpty || address.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Thông tin yêu cầu (${request.code ?? request.id.substring(0, 8)})',
      titleTrailing: widget.onEdit == null
          ? null
          : IconButton(
              tooltip: 'Chỉnh sửa',
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Khách', request.customerName),
          _rowWithCopy(
            context,
            'SĐT',
            request.customerPhone,
            snackMessage: 'Đã copy SĐT',
          ),
          if (request.customerAddress != null &&
              request.customerAddress!.isNotEmpty)
            _row('Địa chỉ', request.customerAddress!),
          _row('Sản phẩm', request.productName),
          if (request.productSerial != null &&
              request.productSerial!.isNotEmpty)
            _row('Serial', request.productSerial!),
          _row('Lỗi', request.issueDescription),
          if (request.customerNote != null &&
              request.customerNote!.trim().isNotEmpty)
            _row('Ghi chú', request.customerNote!.trim()),
          if ((widget.appointmentDate ?? '').trim().isNotEmpty ||
              (widget.appointmentSlot ?? '').trim().isNotEmpty)
            _row(
              'Thời gian hẹn',
              [
                if ((widget.appointmentDate ?? '').trim().isNotEmpty)
                  widget.appointmentDate!.trim(),
                if ((widget.appointmentSlot ?? '').trim().isNotEmpty)
                  widget.appointmentSlot!.trim(),
              ].join(' '),
            ),
          if (request.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Đính kèm', style: text.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < request.attachments.length; i++)
                  MediaTile(
                    url: request.attachments[i].url,
                    mediaType: request.attachments[i].mediaType ?? 'image',
                    width: 64,
                    height: 64,
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MediaViewerPage(
                            items: [
                              for (final a in request.attachments)
                                MediaViewerItem(
                                  url: a.url,
                                  mediaType: a.mediaType ?? 'image',
                                ),
                            ],
                            initialIndex: i,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
          if (_hasBuyerInfo) ...[
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _showBuyer = !_showBuyer),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _showBuyer ? 'Thu gọn' : 'Xem thêm',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      _showBuyer
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (_showBuyer) ...[
              if (request.buyerName != null && request.buyerName!.isNotEmpty)
                _row('Người mua', request.buyerName!),
              if (request.buyerPhone != null && request.buyerPhone!.isNotEmpty)
                _rowWithCopy(
                  context,
                  'SĐT mua',
                  request.buyerPhone!,
                  snackMessage: 'Đã copy SĐT người mua',
                ),
              if (request.buyerAddress != null &&
                  request.buyerAddress!.isNotEmpty)
                _row('Địa chỉ mua', request.buyerAddress!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _copyText(
    BuildContext context,
    String text,
    String snackMessage,
  ) async {
    final v = text.trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (!context.mounted) return;
    AppMessenger.showSnackBar(
      context,
      SnackBar(content: Text(snackMessage)),
    );
  }

  Widget _rowWithCopy(
    BuildContext context,
    String label,
    String value, {
    required String snackMessage,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value)),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copyText(context, value, snackMessage),
          ),
        ],
      ),
    );
  }
}
