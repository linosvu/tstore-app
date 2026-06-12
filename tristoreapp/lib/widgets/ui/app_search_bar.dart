import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/localization/app_localizations.dart';

/// Search field: white surface + hairline border (DMX-style).
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    const borderColor = Color(0xFFE2E8F0);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return Material(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: borderColor, width: 1),
          ),
          child: SizedBox(
            height: AppSpacing.searchBarHeight,
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                prefixIcon: Semantics(
                  label: 'Tìm kiếm',
                  child: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: hasText ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                suffixIcon: hasText
                    ? Semantics(
                        button: true,
                        label: l10n.searchClear,
                        child: IconButton(
                          tooltip: l10n.searchClear,
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                          onPressed: () {
                            controller.clear();
                            onClear?.call();
                            onChanged?.call('');
                          },
                        ),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: AppSpacing.space2,
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        );
      },
    );
  }
}
