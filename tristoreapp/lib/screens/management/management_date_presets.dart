/// Quick date-range presets for management filters (local calendar days).
class ManagementDatePresets {
  static String _isoDate(DateTime d) {
    final y = d.year;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static ({String? from, String? to}) today() {
    final n = DateTime.now();
    final s = _isoDate(n);
    return (from: s, to: s);
  }

  static ({String? from, String? to}) yesterday() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    final s = _isoDate(n);
    return (from: s, to: s);
  }

  static ({String? from, String? to}) last7Days() {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 6));
    return (from: _isoDate(start), to: _isoDate(end));
  }

  static ({String? from, String? to}) thisMonth() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return (from: _isoDate(start), to: _isoDate(now));
  }

  static ({String? from, String? to}) last90Days() {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 89));
    return (from: _isoDate(start), to: _isoDate(end));
  }

  static ({String? from, String? to}) all() => (from: null, to: null);
}
