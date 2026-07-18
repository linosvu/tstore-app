import 'package:flutter/material.dart';
import 'package:tstore/models/service_request.dart';
import 'package:tstore/widgets/ui/section_card.dart';

import '../service_ui.dart';

class TicketLogList extends StatelessWidget {
  const TicketLogList({super.key, required this.logs});

  final List<TicketLogPublic> logs;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Nhật ký',
      child: logs.isEmpty
          ? const Text('Chưa có nhật ký.', style: TextStyle(color: Colors.grey))
          : Column(
              children: [
                for (final log in logs.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.history_rounded, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.action,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (log.reason != null && log.reason!.isNotEmpty)
                                Text('Lý do: ${log.reason}'),
                              if (log.newValue != null &&
                                  log.newValue!.isNotEmpty)
                                Text(log.newValue!),
                              Text(
                                '${log.actorName ?? '—'} · ${formatServiceTime(log.createdAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
