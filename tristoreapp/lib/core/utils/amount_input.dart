// Định dạng số nguyên (đồng / số lượng) khớp backend + admin-web
// (`thousandsGroupSeparator`: dot | comma | space | none).

enum ThousandsGroupSeparatorKey {
  dot,
  comma,
  space,
  none,
}

/// Mặc định giống backend / CurrencyPage (VN).
const ThousandsGroupSeparatorKey kAppDefaultThousandsSeparator =
    ThousandsGroupSeparatorKey.dot;

ThousandsGroupSeparatorKey normalizeThousandsKey(Object? raw) {
  if (raw == 'comma') return ThousandsGroupSeparatorKey.comma;
  if (raw == 'space') return ThousandsGroupSeparatorKey.space;
  if (raw == 'none') return ThousandsGroupSeparatorKey.none;
  return ThousandsGroupSeparatorKey.dot;
}

String separatorChar(ThousandsGroupSeparatorKey key) {
  switch (key) {
    case ThousandsGroupSeparatorKey.comma:
      return ',';
    case ThousandsGroupSeparatorKey.space:
      return ' ';
    case ThousandsGroupSeparatorKey.none:
      return '';
    case ThousandsGroupSeparatorKey.dot:
      return '.';
  }
}

String digitsOnlyIntString(String raw) {
  return raw.replaceAll(RegExp(r'\D'), '');
}

String formatIntegerWithSeparator(int value, ThousandsGroupSeparatorKey key) {
  final n = value;
  final sign = n < 0 ? '-' : '';
  final abs = n.abs();
  final s = abs.toString();
  final ch = separatorChar(key);
  if (ch.isEmpty) {
    return sign + s;
  }
  final parts = <String>[];
  for (var i = s.length; i > 0; i -= 3) {
    parts.add(s.substring(i > 3 ? i - 3 : 0, i));
  }
  return sign + parts.reversed.join(ch);
}

String stripThousandsSeparators(String raw, ThousandsGroupSeparatorKey key) {
  var t = raw.trim();
  switch (key) {
    case ThousandsGroupSeparatorKey.none:
      return digitsOnlyIntString(t);
    case ThousandsGroupSeparatorKey.dot:
      return t.replaceAll('.', '');
    case ThousandsGroupSeparatorKey.comma:
      return t.replaceAll(',', '');
    case ThousandsGroupSeparatorKey.space:
      return t
          .replaceAll(RegExp(r'\s'), '')
          .replaceAll('\u00a0', '');
  }
}

int? parseIntegerLoose(String raw, ThousandsGroupSeparatorKey key) {
  final stripped = stripThousandsSeparators(raw, key);
  if (stripped.isEmpty) return null;
  return int.tryParse(stripped);
}

/// Ký tự cho [FilteringTextInputFormatter] (trước formatter).
RegExp integerThousandsInputAllowPattern(ThousandsGroupSeparatorKey key) {
  switch (key) {
    case ThousandsGroupSeparatorKey.comma:
      return RegExp(r'[0-9,]');
    case ThousandsGroupSeparatorKey.space:
      return RegExp(r'[0-9\s\u00A0]');
    case ThousandsGroupSeparatorKey.none:
      return RegExp(r'[0-9]');
    case ThousandsGroupSeparatorKey.dot:
      return RegExp(r'[0-9.]');
  }
}
