import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/utils/media_upload_flow.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/core/widgets/media_picker_sheet.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';

/// Thêm / xem bằng chứng theo stage.
class EvidenceSection extends StatefulWidget {
  const EvidenceSection({
    super.key,
    required this.ticketId,
    required this.stage,
    required this.evidences,
    required this.onChanged,
    this.readOnly = false,
    this.title = 'Bằng chứng',
  });

  final String ticketId;
  final String stage;
  final List<TicketEvidencePublic> evidences;
  final VoidCallback onChanged;
  final bool readOnly;
  final String title;

  @override
  State<EvidenceSection> createState() => _EvidenceSectionState();
}

class _EvidenceSectionState extends State<EvidenceSection> {
  bool _busy = false;

  List<TicketEvidencePublic> get _stageItems =>
      widget.evidences.where((e) => e.stage == widget.stage).toList();

  Future<void> _add() async {
    if (_busy || widget.readOnly) return;
    final picks = await showMediaPickerSheet(context, allowVideo: true);
    if (picks == null || picks.isEmpty || !mounted) return;
    setState(() => _busy = true);
    final api = context.read<AuthProvider>().api;
    final prov = context.read<ServiceRequestsProvider>();
    try {
      for (final pick in picks) {
        final uploaded = await uploadPickedMedia(pick: pick, api: api);
        if (uploaded == null || uploaded.url.isEmpty) continue;
        await prov.addEvidence(widget.ticketId, {
          'stage': widget.stage,
          'kind': pick.isVideo ? 'video' : 'image',
          'fileUrl': uploaded.url,
        });
      }
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text('Không tải được bằng chứng: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _stageItems;
    return SectionCard(
      title: widget.title,
      titleTrailing: widget.readOnly
          ? null
          : IconButton(
              tooltip: 'Thêm',
              onPressed: _busy ? null : _add,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
            ),
      child: items.isEmpty
          ? const Text('Chưa có bằng chứng.', style: TextStyle(color: Colors.grey))
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < items.length; i++)
                  ActionChip(
                    avatar: Icon(
                      items[i].kind == 'video'
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      size: 16,
                    ),
                    label: Text('${items[i].kind} ${i + 1}'),
                    onPressed: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => MediaViewerPage(
                            items: [
                              for (final e in items)
                                MediaViewerItem(
                                  url: e.fileUrl,
                                  mediaType: e.kind,
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
    );
  }
}
