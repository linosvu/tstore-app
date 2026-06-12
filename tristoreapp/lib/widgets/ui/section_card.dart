import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_ui_extension.dart';

/// Bordered surface block for grouping form/list sections.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.titleTrailing,
    required this.child,
    this.padding,
  });

  final String? title;
  final Widget? titleTrailing;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final ui = context.appUi;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(ui.radiusLg),
        boxShadow: ui.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.cardInnerLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (titleTrailing != null) titleTrailing!,
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
