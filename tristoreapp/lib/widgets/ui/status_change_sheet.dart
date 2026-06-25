import 'package:flutter/material.dart';

import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/widgets/ui/status_badge.dart';

class StatusChangeOption {
  const StatusChangeOption({
    required this.value,
    required this.label,
    required this.tone,
  });

  final String value;
  final String label;
  final StatusBadgeTone tone;
}

/// Bottom sheet chọn trạng thái (radio + Hủy / Xác nhận) — dùng cho quản lý.
Future<String?> showStatusChangeSheet({
  required BuildContext context,
  required String title,
  required String currentStatusLabel,
  required StatusBadgeTone currentStatusTone,
  required String statusFieldLabel,
  required List<StatusChangeOption> options,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  if (options.isEmpty) return null;

  String? selectedStatus;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final maxListH = MediaQuery.sizeOf(ctx).height * 0.42;
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final canConfirm =
              selectedStatus != null && options.any((o) => o.value == selectedStatus);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                0,
                AppSpacing.screenHorizontal,
                AppSpacing.space4 + MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Row(
                    children: [
                      Text(
                        '$statusFieldLabel: ',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      StatusBadge(
                        label: currentStatusLabel,
                        tone: currentStatusTone,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space2),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxListH),
                    child: ListView(
                      shrinkWrap: true,
                      children: options.map((opt) {
                        return RadioListTile<String>(
                          value: opt.value,
                          groupValue: selectedStatus,
                          contentPadding: EdgeInsets.zero,
                          title: Text(opt.label),
                          secondary: StatusBadge(
                            label: opt.label,
                            tone: opt.tone,
                          ),
                          onChanged: (v) {
                            setModalState(() => selectedStatus = v);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(cancelLabel),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.space2),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              canConfirm ? () => Navigator.pop(ctx, true) : null,
                          child: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (confirmed != true || selectedStatus == null) return null;
  return selectedStatus;
}
