import 'package:flutter/material.dart';

import '../service_ui.dart';

class RepairStepper extends StatelessWidget {
  const RepairStepper({
    super.key,
    required this.status,
    this.customerRejectPending = false,
  });

  final String status;
  final bool customerRejectPending;

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
            Column(
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
                  repairStepLabels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == idx ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
