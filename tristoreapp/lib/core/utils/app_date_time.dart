/// Múi giờ nghiệp vụ — khớp backend `Asia/Ho_Chi_Minh` (UTC+7, không DST).
class AppDateTime {
  AppDateTime._();

  static const Duration vnOffset = Duration(hours: 7);

  /// Thời điểm hiện tại theo lịch Việt Nam.
  static DateTime nowVn() => DateTime.now().toUtc().add(vnOffset);

  /// `yyyy-MM-dd` theo lịch Việt Nam.
  static String calendarDate([DateTime? instant]) {
    final vn = (instant ?? DateTime.now()).toUtc().add(vnOffset);
    final m = vn.month.toString().padLeft(2, '0');
    final d = vn.day.toString().padLeft(2, '0');
    return '${vn.year}-$m-$d';
  }

  /// Chuyển instant UTC/local sang thời gian lịch VN (dùng khi format hiển thị).
  static DateTime toVn(DateTime instant) => instant.toUtc().add(vnOffset);
}
