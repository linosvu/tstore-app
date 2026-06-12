import 'package:flutter/material.dart';

import '../../core/theme/app_ui_extension.dart';

/// Compact status tag (DMX-style: rounded rect + hairline border).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = StatusBadgeTone.neutral,
    this.expand = false,
  });

  final String label;
  final StatusBadgeTone tone;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ui = context.appUi;
    late Color fg;
    late Color bg;
    switch (tone) {
      case StatusBadgeTone.success:
        fg = const Color(0xFF065F46);
        bg = ui.success.withValues(alpha: 0.12);
        break;
      case StatusBadgeTone.warning:
        fg = const Color(0xFF92400E);
        bg = ui.warning.withValues(alpha: 0.14);
        break;
      case StatusBadgeTone.error:
        fg = const Color(0xFFB91C1C);
        bg = ui.error.withValues(alpha: 0.12);
        break;
      case StatusBadgeTone.info:
        fg = const Color(0xFF1565C0);
        bg = ui.info.withValues(alpha: 0.12);
        break;
      case StatusBadgeTone.neutral:
        fg = scheme.onSurfaceVariant;
        bg = scheme.surfaceContainerHighest.withValues(alpha: 0.65);
        break;
    }
    final radius = BorderRadius.circular(ui.statusPillRadius);
    return Semantics(
      label: 'Trạng thái: $label',
      readOnly: true,
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(
            color: fg.withValues(alpha: 0.28),
            width: ui.hairline,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: expand ? TextAlign.center : TextAlign.start,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 11,
                height: 1.2,
              ),
        ),
      ),
    );
  }
}

enum StatusBadgeTone { neutral, success, warning, error, info }
