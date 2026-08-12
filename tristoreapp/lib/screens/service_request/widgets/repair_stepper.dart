import 'package:flutter/material.dart';

import '../service_ui.dart';

class RepairStepper extends StatelessWidget {
  const RepairStepper({
    super.key,
    required this.status,
    this.customerRejectPending = false,
    this.browsable = false,
    this.previewIndex,
    this.onStepTap,
  });

  final String status;
  final bool customerRejectPending;
  /// Cho phép bấm các bước đã qua / hiện tại để xem lại (không rewind).
  final bool browsable;
  /// Bước đang xem lại (null = đang ở bước thật theo status).
  final int? previewIndex;
  final void Function(int index)? onStepTap;

  @override
  Widget build(BuildContext context) {
    final idx = repairStepIndex(
      status,
      customerRejectPending: customerRejectPending,
    );
    final focus = previewIndex ?? idx;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < repairStepLabels.length; i++) ...[
            if (i > 0)
              Container(
                width: 16,
                height: 2,
                color: i <= idx
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
            if (onStepTap != null && browsable && i <= idx && i < 5)
              InkWell(
                onTap: () => onStepTap!.call(i),
                borderRadius: BorderRadius.circular(14),
                child: _stepContent(
                  context,
                  i,
                  idx,
                  focus,
                  repairStepLabels[i],
                  tappable: true,
                ),
              )
            else
              _stepContent(
                context,
                i,
                idx,
                focus,
                repairStepLabels[i],
              ),
          ],
        ],
      ),
    );
  }

  Widget _stepContent(
    BuildContext context,
    int i,
    int currentIdx,
    int focusIdx,
    String label, {
    bool tappable = false,
  }) {
    final done = i <= currentIdx;
    final focused = i == focusIdx;
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: done
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
          child: Text(
            '${i + 1}',
            style: TextStyle(
              fontSize: 11,
              color: done ? Colors.white : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: focused ? FontWeight.w700 : FontWeight.w400,
            decoration: tappable ? TextDecoration.underline : null,
            color: focused && previewIndex != null && i < currentIdx
                ? Theme.of(context).colorScheme.tertiary
                : null,
          ),
        ),
      ],
    );
  }
}
