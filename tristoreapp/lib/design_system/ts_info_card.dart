import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/theme/app_ui_extension.dart';

/// Frosted info strip on gradient header.
class TsInfoCard extends StatelessWidget {
  const TsInfoCard({
    super.key,
    required this.title,
    required this.value,
    this.leadingIcon = Icons.auto_awesome_outlined,
  });

  final String title;
  final String value;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final ui = context.appUi;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(ui.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(leadingIcon, color: AppColors.onPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.onPrimary.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.points,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
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
