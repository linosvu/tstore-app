import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/core/utils/media_upload_flow.dart';
import 'package:tstore/core/widgets/app_messenger.dart';
import 'package:tstore/core/widgets/media_picker_sheet.dart';
import 'package:tstore/core/widgets/media_tile.dart';
import 'package:tstore/core/widgets/media_viewer_page.dart';
import 'package:tstore/core/widgets/pending_media_tile.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/providers/service_requests_provider.dart';
import 'package:tstore/widgets/ui/section_card.dart';

/// Thêm / xem bằng chứng theo stage (thumbnail nhỏ).
class EvidenceSection extends StatefulWidget {
  const EvidenceSection({
    super.key,
    required this.ticketId,
    required this.stage,
    required this.evidences,
    required this.onChanged,
    this.readOnly = false,
    this.title = 'Bằng chứng',
    this.noteField,
    this.wrapInCard = true,
  });

  final String ticketId;
  final String stage;
  final List<TicketEvidencePublic> evidences;
  final VoidCallback onChanged;
  final bool readOnly;
  final String title;
  /// Ghi chú dưới bằng chứng (vd. tiếp nhận SC).
  final Widget? noteField;
  /// false: nhúng nội dung vào SectionCard cha (không bọc thêm card).
  final bool wrapInCard;

  @override
  State<EvidenceSection> createState() => _EvidenceSectionState();
}

class _EvidenceSectionState extends State<EvidenceSection> {
  bool _busy = false;
  final List<PendingMediaUpload> _pending = [];
  final Set<String> _cancelledPendingIds = {};

  List<TicketEvidencePublic> get _stageItems => widget.evidences
      .where((e) => e.stage == widget.stage && (e.fileUrl).trim().isNotEmpty)
      .toList();

  void _cancelPending(PendingMediaUpload pending) {
    _cancelledPendingIds.add(pending.id);
    if (!mounted) return;
    setState(() {
      _pending.removeWhere((e) => e.id == pending.id);
    });
  }

  Future<void> _confirmRemove(TicketEvidencePublic item) async {
    if (_busy || widget.readOnly) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deliveryRemoveImage),
        content: Text(l10n.productsRemoveImageTooltip),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context
          .read<ServiceRequestsProvider>()
          .removeEvidence(widget.ticketId, item.id);
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          SnackBar(content: Text('Không xoá được bằng chứng: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    if (_busy || widget.readOnly) return;
    final picks = await showMediaPickerSheet(context, allowVideo: true);
    if (picks == null || picks.isEmpty || !mounted) return;

    setState(() => _busy = true);
    final api = context.read<AuthProvider>().api;
    final prov = context.read<ServiceRequestsProvider>();
    var anyAdded = false;
    try {
      for (final pick in picks) {
        if (!mounted) return;
        final pending = enqueuePendingMedia(
          pick: pick,
          scopeKey: widget.stage,
        );
        setState(() => _pending.add(pending));

        try {
          final uploaded = await uploadPickedMedia(
            pick: pick,
            api: api,
            onProgress: (v) {
              if (!mounted) return;
              if (_cancelledPendingIds.contains(pending.id)) return;
              setState(() => pending.progress = v);
            },
          );

          if (!mounted) return;
          if (_cancelledPendingIds.contains(pending.id)) continue;
          if (uploaded == null || uploaded.url.trim().isEmpty) continue;

          await prov.addEvidence(widget.ticketId, {
            'stage': widget.stage,
            'kind': pick.isVideo ? 'video' : 'image',
            'fileUrl': uploaded.url,
          });
          anyAdded = true;
        } catch (e) {
          if (mounted) {
            AppMessenger.showSnackBar(
              context,
              SnackBar(content: Text('Không tải được bằng chứng: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() => _pending.removeWhere((e) => e.id == pending.id));
            _cancelledPendingIds.remove(pending.id);
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (anyAdded) widget.onChanged();
      }
    }
  }

  Widget? get _addButton => widget.readOnly
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
        );

  @override
  Widget build(BuildContext context) {
    final items = _stageItems;
    final canDelete = !widget.readOnly && !_busy;
    final canCancelPending = !widget.readOnly;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (items.isEmpty && _pending.isEmpty)
          const Text(
            'Chưa có thông tin',
            style: TextStyle(color: Colors.grey),
          )
        else
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _pending)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        LocalMediaPreviewTile(
                          localPath: p.localPath,
                          isVideo: p.isVideo,
                          loading: true,
                          error: false,
                          progress: p.progress,
                          width: 64,
                          height: 64,
                        ),
                        if (canCancelPending)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.75),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => _cancelPending(p),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                for (var i = 0; i < items.length; i++)
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        MediaTile(
                          url: items[i].fileUrl,
                          mediaType: items[i].kind,
                          width: 64,
                          height: 64,
                          onTap: () {
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
                        if (canDelete)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Material(
                              color: Colors.black.withValues(alpha: 0.75),
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => _confirmRemove(items[i]),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        if (widget.noteField != null) ...[
          const SizedBox(height: 12),
          widget.noteField!,
        ],
      ],
    );

    if (widget.wrapInCard) {
      return SectionCard(
        title: widget.title,
        titleTrailing: _addButton,
        child: body,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (_addButton != null) _addButton!,
            ],
          ),
          const SizedBox(height: 12),
        ],
        body,
      ],
    );
  }
}
