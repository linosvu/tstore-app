import 'package:flutter/material.dart';
import 'package:tstore/core/constants/app_colors.dart';

import '../service_ui.dart';

/// Banner đếm ngược / quá hạn theo deadlineAt.
class CountdownBanner extends StatelessWidget {
  const CountdownBanner({
    super.key,
    this.deadlineAt,
    this.isOverdue = false,
    this.label = 'Hạn xử lý',
  });

  final String? deadlineAt;
  final bool isOverdue;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (deadlineAt == null || deadlineAt!.isEmpty) {
      return const SizedBox.shrink();
    }
    final deadline = DateTime.tryParse(deadlineAt!);
    if (deadline == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final overdue = isOverdue || deadline.isBefore(now);
    final diff = deadline.difference(now);
    String remaining;
    if (overdue) {
      final late = now.difference(deadline);
      remaining = 'Quá hạn ${late.inHours}h ${late.inMinutes.remainder(60)}p';
    } else if (diff.inDays >= 1) {
      remaining = 'Còn ${diff.inDays} ngày ${diff.inHours.remainder(24)}h';
    } else {
      remaining = 'Còn ${diff.inHours}h ${diff.inMinutes.remainder(60)}p';
    }

    final bg = overdue
        ? AppColors.error.withValues(alpha: 0.12)
        : AppColors.warning.withValues(alpha: 0.14);
    final fg = overdue ? AppColors.error : const Color(0xFF92400E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            overdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
            color: fg,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label · ${formatServiceTime(deadlineAt)}',
                  style: TextStyle(fontSize: 12, color: fg),
                ),
                Text(
                  remaining,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: fg,
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
