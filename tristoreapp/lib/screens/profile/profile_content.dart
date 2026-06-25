import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tstore/core/widgets/app_messenger.dart';

import '../../core/config/api_config.dart';
import '../../core/config/app_template_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/routes.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/utils/avatar_compress.dart' show uploadAvatarFromPath;
import '../../core/utils/user_role_labels.dart';
import '../../design_system/design_system.dart';
import '../../models/auth_user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/ui/menu_group_card.dart';
import 'profile_account_dialogs.dart';

/// Nội dung hồ sơ dùng chung — embed trong Cài đặt hoặc màn độc lập.
class ProfileContent extends StatefulWidget {
  const ProfileContent({
    super.key,
    this.embedInSettings = false,
  });

  /// `true` khi nằm trong [SettingsScreen] — header gọn, không nút Home/Cài đặt.
  final bool embedInSettings;

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  bool _avatarBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthProvider>().refreshMe();
    });
  }

  String _initials(String fullName) {
    final parts =
        fullName.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _buildAvatar(AuthUser user) {
    final raw = user.avatarUrl;
    if (raw != null && raw.isNotEmpty) {
      String? networkUrl;
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        networkUrl = raw;
      } else if (raw.startsWith('/')) {
        networkUrl =
            ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '') + raw;
      }
      if (networkUrl != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(44),
          child: CachedNetworkImage(
            imageUrl: networkUrl,
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            memCacheWidth: 88,
            memCacheHeight: 88,
            placeholder: (_, __) => Container(
              width: 88,
              height: 88,
              color: Colors.grey.shade200,
            ),
            errorWidget: (_, __, ___) => _avatarFallback(user),
          ),
        );
      }
      if (raw.startsWith('data:image')) {
        final i = raw.indexOf(',');
        if (i > 0) {
          try {
            final bytes = base64Decode(raw.substring(i + 1));
            return ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: Image.memory(
                Uint8List.fromList(bytes),
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(user),
              ),
            );
          } catch (_) {}
        }
      }
    }
    return _avatarFallback(user);
  }

  Future<void> _showAvatarSheet(AppLocalizations l10n, AuthUser user) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn ảnh từ thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadAvatar(ImageSource.gallery, l10n);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadAvatar(ImageSource.camera, l10n);
              },
            ),
            if (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: AppColors.error.withValues(alpha: 0.9),
                ),
                title: Text(
                  'Xóa ảnh đại diện',
                  style: TextStyle(
                    color: AppColors.error.withValues(alpha: 0.95),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _clearAvatar(l10n);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(
    ImageSource source,
    AppLocalizations l10n,
  ) async {
    final picker = ImagePicker();
    try {
      final x = await picker.pickImage(source: source);
      if (x == null || !mounted) return;
      setState(() => _avatarBusy = true);
      final avatarUrl = await uploadAvatarFromPath(
        x.path,
        context.read<AuthProvider>().api,
      );
      if (!mounted) return;
      if (avatarUrl == null) {
        setState(() => _avatarBusy = false);
        AppMessenger.showSnackBar(
          context,
          const SnackBar(content: Text('Không xử lý được ảnh.')),
        );
        return;
      }
      final err =
          await context.read<AuthProvider>().patchProfile(avatarUrl: avatarUrl);
      if (!mounted) return;
      setState(() => _avatarBusy = false);
      if (err != null) {
        AppMessenger.showSnackBar(context, SnackBar(content: Text(err)));
      } else {
        AppMessenger.showSnackBar(
          context,
          SnackBar(
            content: Text(l10n.success),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _avatarBusy = false);
      AppMessenger.showSnackBar(
        context,
        SnackBar(content: Text('Chọn ảnh thất bại: $e')),
      );
    }
  }

  Future<void> _clearAvatar(AppLocalizations l10n) async {
    setState(() => _avatarBusy = true);
    final err =
        await context.read<AuthProvider>().patchProfile(clearAvatar: true);
    if (!mounted) return;
    setState(() => _avatarBusy = false);
    if (err != null) {
      AppMessenger.showSnackBar(context, SnackBar(content: Text(err)));
    } else {
      AppMessenger.showSnackBar(
        context,
        SnackBar(
          content: Text(l10n.success),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _buildAvatarWithAction(AuthUser user, AppLocalizations l10n) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _avatarBusy ? null : () => _showAvatarSheet(l10n, user),
          customBorder: const CircleBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _buildAvatar(user),
              if (_avatarBusy)
                ClipRRect(
                  borderRadius: BorderRadius.circular(44),
                  child: const SizedBox(
                    width: 88,
                    height: 88,
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!_avatarBusy)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback(AuthUser user) {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(user.fullName),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _editName(AppLocalizations l10n, AuthUser current) async {
    final c = TextEditingController(text: current.fullName);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editYourName),
        content: TextField(
          controller: c,
          decoration: InputDecoration(
            labelText: l10n.yourName,
            hintText: l10n.enterYourName,
          ),
          maxLength: 120,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final err = await context
                  .read<AuthProvider>()
                  .patchProfile(fullName: c.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              if (err != null) {
                AppMessenger.showSnackBar(context, SnackBar(content: Text(err)));
              } else {
                AppMessenger.showSnackBar(
                  context,
                  SnackBar(
                    content: Text(l10n.success),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    AppLocalizations l10n,
    AuthUser user,
    String joined,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.space4),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatarWithAction(user, l10n),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _editName(l10n, user),
                      child: Text(
                        user.fullName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.onPrimary.withValues(alpha: 0.9),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      avatar: const Icon(
                        Icons.badge_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: Text(roleLabelVi(user.role)),
                      backgroundColor: Colors.white.withValues(alpha: 0.95),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TsInfoCard(
            title: 'Tham gia',
            value: joined,
            leadingIcon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().user;

    if (user == null) {
      return Padding(
        padding: AppSpacing.screenPaddingAll,
        child: Column(
          children: [
            const Text('Chưa đăng nhập.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (_) => false,
              ),
              child: const Text('Đăng nhập'),
            ),
          ],
        ),
      );
    }

    final joined = DateFormat.yMMMd('vi').format(user.createdAt.toLocal());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedInSettings)
          _buildEmbeddedHeader(context, l10n, user, joined)
        else
          TsProfileHeader(
            title: l10n.profileTitle,
            avatar: _buildAvatarWithAction(user, l10n),
            displayName: user.fullName,
            onDisplayNameTap: () => _editName(l10n, user),
            subtitle: user.email,
            badge: Chip(
              avatar: const Icon(
                Icons.badge_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              label: Text(roleLabelVi(user.role)),
              backgroundColor: Colors.white.withValues(alpha: 0.95),
              visualDensity: VisualDensity.compact,
            ),
            infoCard: TsInfoCard(
              title: 'Tham gia',
              value: joined,
              leadingIcon: Icons.calendar_today_outlined,
            ),
          ),
        const SizedBox(height: AppSpacing.sectionGap),
        MenuGroupCard(
          title: l10n.settingsAccountSection,
          items: [
            MenuGroupItem(
              title: l10n.profileEmail,
              subtitle: user.email,
              icon: Icons.email_outlined,
              iconColor: AppColors.primary,
              onTap: () => ProfileAccountDialogs.editEmail(context, l10n, user),
            ),
            MenuGroupItem(
              title: l10n.profileChangePassword,
              icon: Icons.lock_outline_rounded,
              iconColor: AppColors.secondary,
              onTap: () =>
                  ProfileAccountDialogs.changePassword(context, l10n),
            ),
          ],
        ),
        if (AppTemplateConfig.organizationLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sectionGap),
          MenuGroupCard(
            items: [
              MenuGroupItem(
                title: 'Cửa hàng',
                subtitle: AppTemplateConfig.organizationLabel,
                icon: Icons.store_mall_directory_outlined,
                iconColor: AppColors.primary,
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.sectionGap),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(
              color: AppColors.error.withValues(alpha: 0.5),
            ),
          ),
          onPressed: () => ProfileAccountDialogs.confirmLogout(context, l10n),
          child: Text(l10n.profileLogoutTitle),
        ),
      ],
    );
  }
}
