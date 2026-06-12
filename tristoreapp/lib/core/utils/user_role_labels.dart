/// Nhãn vai trò hiển thị (tiếng Việt), khớp enum backend.
String roleLabelVi(String role) {
  switch (role) {
    case 'admin':
      return 'Quản trị viên';
    case 'manager':
      return 'Quản lý';
    case 'staff':
      return 'Nhân viên';
    case 'user':
      return 'Khách hàng';
    default:
      return 'Người dùng';
  }
}
