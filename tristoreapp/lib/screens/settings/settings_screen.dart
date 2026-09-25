import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/constants/app_colors.dart';
import 'package:tstore/core/constants/app_spacing.dart';
import 'package:tstore/core/constants/routes.dart';
import 'package:tstore/core/localization/app_localizations.dart';
import 'package:tstore/design_system/design_system.dart';
import 'package:tstore/providers/auth_provider.dart';
import 'package:tstore/screens/profile/profile_content.dart';
import 'package:tstore/screens/tristore/dashboard_shortcuts.dart';
import 'package:tstore/widgets/app_version_label.dart';
import 'package:tstore/widgets/ui/branded_app_bar.dart';
import 'package:tstore/widgets/ui/menu_group_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: BrandedAppBar(
        title: Text(
          l10n.settings,
          style: const TextStyle(
            color: AppColors.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.space3),
                  if (user != null) ...[
                    ProfileContent(
                      embedInSettings: true,
                      belowHeader: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Phím tắt',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.space2),
                          TsCompactServiceGrid(
                            items:
                                buildDashboardShortcutItems(context, l10n),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      'Chưa đăng nhập.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (_) => false,
                      ),
                      child: const Text('Đăng nhập'),
                    ),
                  ],
                  if (kDebugMode) ...[
                    const SizedBox(height: AppSpacing.sectionGap),
                    MenuGroupCard(
                      items: [
                        MenuGroupItem(
                          title: 'Design System Gallery',
                          subtitle: 'Chỉ bản debug',
                          icon: Icons.palette_outlined,
                          iconColor: AppColors.primary,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.designSystemGallery,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.space3),
                ],
              ),
            ),
          ),
          const AppVersionLabel(),
        ],
      ),
    );
  }
}
