import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_spacing.dart';
import '../core/localization/app_localizations.dart';

class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  Future<PackageInfo> _loadInfo() => PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<PackageInfo>(
      future: _loadInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final version = info?.version ?? '—';
        final build = info?.buildNumber ?? '—';
        return Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.space3,
            bottom: AppSpacing.space2,
          ),
          child: Center(
            child: Text(
              '${l10n.settingsAppVersion} $version · ${l10n.settingsAppBuild} $build',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
          ),
        );
      },
    );
  }
}
