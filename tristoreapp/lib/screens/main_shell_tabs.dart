/// Indices for [MainShell] / [PrimaryBottomNav] — single source of truth.
///
/// Order: Home → Orders → Giao Hàng (hub chuẩn bị + giao) → Sửa chữa → Thông báo.
abstract final class MainShellTab {
  static const int home = 0;
  static const int orders = 1;
  static const int delivery = 2;
  static const int repairs = 3;
  static const int notifications = 4;

  static const int count = 5;
}
