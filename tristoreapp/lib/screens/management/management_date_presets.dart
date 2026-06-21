import 'package:tstore/core/utils/app_date_time.dart';

/// Quick date-range presets for management filters (calendar days in VN timezone).
class ManagementDatePresets {
  static String _isoDate(DateTime d) => AppDateTime.calendarDate(d);

  static ({String? from, String? to}) today() {
    final s = AppDateTime.calendarDate();
    return (from: s, to: s);
  }

  static ({String? from, String? to}) yesterday() {
    final n = AppDateTime.nowVn().subtract(const Duration(days: 1));
    final s = _isoDate(n);
    return (from: s, to: s);
  }

  static ({String? from, String? to}) last7Days() {
    final end = AppDateTime.nowVn();
    final start = end.subtract(const Duration(days: 6));
    return (from: _isoDate(start), to: _isoDate(end));
  }

  static ({String? from, String? to}) thisMonth() {
    final now = AppDateTime.nowVn();
    final start = DateTime(now.year, now.month, 1);
    return (from: _isoDate(start), to: _isoDate(now));
  }

  static ({String? from, String? to}) last90Days() {
    final end = AppDateTime.nowVn();
    final start = end.subtract(const Duration(days: 89));
    return (from: _isoDate(start), to: _isoDate(end));
  }

  static ({String? from, String? to}) all() => (from: null, to: null);
}
