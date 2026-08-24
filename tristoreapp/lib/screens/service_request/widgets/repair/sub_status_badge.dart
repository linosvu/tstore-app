import 'package:flutter/material.dart';

import '../service_ui.dart';

class RepairSubStatusBadge extends StatelessWidget {
  const RepairSubStatusBadge({super.key, required this.subStatus});

  final String? subStatus;

  @override
  Widget build(BuildContext context) {
    if (subStatus == null || subStatus!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(
            repairSubStatusLabel(subStatus),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
