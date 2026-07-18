import 'package:flutter/material.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/widgets/ui/section_card.dart';

import '../service_ui.dart';

/// Thông tin YC gốc (khoá) hiển thị trên phiếu con.
class LockedRequestInfoCard extends StatelessWidget {
  const LockedRequestInfoCard({super.key, required this.request});

  final ServiceRequestBrief request;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SectionCard(
      title: 'Thông tin yêu cầu (${request.code ?? request.id.substring(0, 8)})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Kênh', channelLabel(request.channel)),
          _row('Khách', request.customerName),
          _row('SĐT', request.customerPhone),
          if (request.customerPhone2 != null &&
              request.customerPhone2!.isNotEmpty)
            _row('SĐT 2', request.customerPhone2!),
          if (request.customerAddress != null &&
              request.customerAddress!.isNotEmpty)
            _row('Địa chỉ', request.customerAddress!),
          _row('Sản phẩm', request.productName),
          if (request.productSerial != null &&
              request.productSerial!.isNotEmpty)
            _row('Serial', request.productSerial!),
          _row('Lỗi', request.issueDescription),
          if (request.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Đính kèm', style: text.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in request.attachments)
                  ActionChip(
                    label: Text(
                      a.mediaType == 'video' ? 'Video' : 'Ảnh',
                    ),
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MediaViewerPage(
                            items: [
                              MediaViewerItem(
                                url: a.url,
                                mediaType: a.mediaType ?? 'image',
                              ),
                            ],
                            initialIndex: 0,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
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
}
