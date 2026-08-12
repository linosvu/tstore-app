import 'package:flutter/material.dart';

enum TicketFlowStepState { pending, active, done, failed }

/// Thanh bước list (SC 5 bước / Hỗ trợ 3 bước) — cùng màu & khoảng cách.
class TicketFlowProgressBar extends StatelessWidget {
  const TicketFlowProgressBar({
    super.key,
    required this.labels,
    required this.activeIndex,
    this.failed = false,
    this.stepSubtitles = const [],
  });

  final List<String> labels;

  /// 0..n-1 = bước đang làm; >= n = tất cả done.
  final int activeIndex;
  final bool failed;

  /// Tên NV dưới mỗi bước (cùng độ dài labels hoặc rỗng).
  final List<String?> stepSubtitles;

  TicketFlowStepState _stateFor(int i) {
    if (failed) {
      if (i < activeIndex) return TicketFlowStepState.done;
      if (i == activeIndex) return TicketFlowStepState.failed;
      return TicketFlowStepState.pending;
    }
    if (activeIndex >= labels.length) return TicketFlowStepState.done;
    if (i < activeIndex) return TicketFlowStepState.done;
    if (i == activeIndex) return TicketFlowStepState.active;
    return TicketFlowStepState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final steps = List.generate(
      labels.length,
      (i) => (labels[i], _stateFor(i)),
    );

    Color colorOf(TicketFlowStepState state) {
      switch (state) {
        case TicketFlowStepState.done:
          return const Color(0xFF22C55E);
        case TicketFlowStepState.active:
          return const Color(0xFF5C60E6);
        case TicketFlowStepState.failed:
          return scheme.error;
        case TicketFlowStepState.pending:
          return scheme.outlineVariant;
      }
    }

    final connectorColor = (steps[0].$2 == TicketFlowStepState.pending)
        ? scheme.outlineVariant
        : const Color(0xFF5C60E6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 26,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = steps.length;
              final stepWidth = constraints.maxWidth / count;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: stepWidth / 2,
                    right: stepWidth / 2,
                    top: 11,
                    child: Container(height: 2, color: connectorColor),
                  ),
                  Row(
                    children: List.generate(count, (i) {
                      final state = steps[i].$2;
                      final color = colorOf(state);
                      return Expanded(
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: state == TicketFlowStepState.pending
                                  ? Colors.transparent
                                  : color,
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Center(
                              child: state == TicketFlowStepState.done
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : Text(
                                      '${i + 1}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: state ==
                                                    TicketFlowStepState
                                                        .pending
                                                ? color
                                                : Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: steps.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final sub = i < stepSubtitles.length ? stepSubtitles[i] : null;
            final assignedName = (sub ?? '').trim();
            return Expanded(
              child: Column(
                children: [
                  Text(
                    s.$1,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 9,
                        ),
                  ),
                  if (assignedName.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      assignedName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontSize: 9,
                          ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
