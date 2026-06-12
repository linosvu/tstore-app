import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Debug-only showcase of design system components.
class DesignSystemGalleryScreen extends StatefulWidget {
  const DesignSystemGalleryScreen({super.key});

  @override
  State<DesignSystemGalleryScreen> createState() =>
      _DesignSystemGalleryScreenState();
}

class _DesignSystemGalleryScreenState extends State<DesignSystemGalleryScreen> {
  String _chipId = 'a';
  String _tabId = 'all';
  int _navIndex = 0;
  int _addressIdx = 0;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Chỉ dùng trong bản debug.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Design System')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          const TsPageTitle(title: 'Hoạt động (mẫu)'),
          TsCategoryChipRow(
            items: const [
              TsCategoryChipItem(id: 'a', label: 'Bảo dưỡng', icon: Icons.ac_unit),
              TsCategoryChipItem(id: 'b', label: 'Sửa chữa', icon: Icons.build),
            ],
            selectedId: _chipId,
            onSelected: (id) => setState(() => _chipId = id),
          ),
          const SizedBox(height: 8),
          TsStatusTabs(
            tabs: const [
              TsStatusTabItem(id: 'all', label: 'Chờ thực hiện'),
              TsStatusTabItem(id: 'active', label: 'Đang thực hiện'),
              TsStatusTabItem(id: 'done', label: 'Hoàn tất'),
            ],
            selectedId: _tabId,
            onSelected: (id) => setState(() => _tabId = id),
          ),
          const SizedBox(height: 24),
          const TsEmptyErrorState(
            title: 'Ứng dụng tạm gián đoạn',
            subtitle: 'Bạn vui lòng thực hiện lại sau ít phút',
            onRetry: _noop,
          ),
          const SizedBox(height: 24),
          TsProfileHeader(
            title: 'Cá nhân',
            avatar: CircleAvatar(child: Text('VC')),
            displayName: 'Vũ Chung',
            subtitle: '0962779762',
            infoCard: const TsInfoCard(
              title: 'Vai trò',
              value: 'Nhân viên',
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TsMenuGroupCard(
              title: 'Tài khoản',
              items: [
                MenuGroupItem(
                  title: 'Sửa thông tin',
                  icon: Icons.person_outline,
                  onTap: _noop,
                ),
              ],
            ),
          ),
          TsAddressRadioTile(
            value: 0,
            groupValue: _addressIdx,
            contactLine: 'Anh Vũ (0962779762)',
            addressLine: '123 Đường ABC, Quận 1, TP.HCM',
            isDefault: true,
            onSelect: () => setState(() => _addressIdx = 0),
            onEdit: _noop,
          ),
          TsAddLinkRow(label: 'Thêm địa chỉ mới', onTap: _noop),
          const TsStickyConfirmBar(label: 'Xác nhận', onPressed: _noop),
        ],
      ),
      bottomNavigationBar: TsBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          TsBottomNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Trang chủ',
          ),
          TsBottomNavItem(
            icon: Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long_rounded,
            label: 'Đơn hàng',
          ),
        ],
      ),
    );
  }

  static void _noop() {}
}
