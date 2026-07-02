import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/branded_app_bar.dart';
import '../../widgets/ui/menu_group_card.dart';
import '../../widgets/app_version_label.dart';
import '../profile/profile_content.dart';

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
                  if (user != null)
                    const ProfileContent(embedInSettings: true)
                  else ...[
                    Text(
                      'Chưa đăng nhập.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
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
