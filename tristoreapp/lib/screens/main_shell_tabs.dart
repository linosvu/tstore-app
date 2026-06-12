/// Indices for [MainShell] / [PrimaryBottomNav] — single source of truth.
///
/// Order: Home → Orders → Giao Hàng (hub chuẩn bị + giao) → Profile.
abstract final class MainShellTab {
  static const int home = 0;
  static const int orders = 1;
  static const int delivery = 2;
  static const int profile = 3;

  static const int count = 4;
}
