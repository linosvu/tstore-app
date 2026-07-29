import 'package:flutter/material.dart';

import '../service_ui.dart';

class RepairStepper extends StatelessWidget {
  const RepairStepper({
    super.key,
    required this.status,
    this.customerRejectPending = false,
    this.editable = false,
    this.onStepTap,
  });

  final String status;
  final bool customerRejectPending;
  final bool editable;
  final void Function(int index)? onStepTap;

  @override
  Widget build(BuildContext context) {
    final idx = repairStepIndex(
      status,
      customerRejectPending: customerRejectPending,
    );
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
            if (onStepTap != null && editable && i < idx)
              InkWell(
                onTap: () => onStepTap!.call(i),
                borderRadius: BorderRadius.circular(14),
                child: _stepContent(
                  context,
                  i,
                  idx,
                  repairStepLabels[i],
                  tappable: true,
                ),
              )
            else
              _stepContent(context, i, idx, repairStepLabels[i]),
          ],
        ],
      ),
    );
  }

  Widget _stepContent(
    BuildContext context,
    int i,
    int idx,
    String label, {
    bool tappable = false,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: i <= idx
              ? Theme.of(context).colorScheme.primary
              : Colors.grey.shade300,
          child: Text(
            '${i + 1}',
            style: TextStyle(
              fontSize: 11,
              color: i <= idx ? Colors.white : Colors.black54,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400,
            decoration: tappable ? TextDecoration.underline : null,
          ),
        ),
      ],
    );
  }
}
