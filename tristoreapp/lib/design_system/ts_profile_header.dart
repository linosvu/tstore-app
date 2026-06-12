import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';

/// Gradient profile header (DMX Cá nhân).
class TsProfileHeader extends StatelessWidget {
  const TsProfileHeader({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
    required this.avatar,
    required this.displayName,
    this.subtitle,
    this.badge,
    this.infoCard,
    this.onDisplayNameTap,
  });

  final String title;
  final Widget? leading;
  final List<Widget> actions;
  final Widget avatar;
  final String displayName;
  final String? subtitle;
  final Widget? badge;
  final Widget? infoCard;
  final VoidCallback? onDisplayNameTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space1),
              child: Row(
                children: [
                  if (leading != null)
                    leading!
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (actions.isEmpty)
                    const SizedBox(width: 48)
                  else
                    Row(mainAxisSize: MainAxisSize.min, children: actions),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.space4),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  avatar,
                  const SizedBox(width: AppSpacing.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: onDisplayNameTap,
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: AppColors.onPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 8),
                              badge!,
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              color: AppColors.onPrimary.withValues(alpha: 0.85),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (infoCard != null) ...[
              const SizedBox(height: AppSpacing.space4),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  0,
                  AppSpacing.screenHorizontal,
                  AppSpacing.space4,
                ),
                child: infoCard!,
              ),
            ] else
              const SizedBox(height: AppSpacing.space4),
          ],
        ),
      ),
    );
  }
}
