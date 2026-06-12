import 'package:flutter/services.dart';

import 'package:tstore/core/utils/amount_input.dart';

/// Bàn phím gợi ý: có dấu thập phân khi cần gõ phân cách (chấm/phẩy).
TextInputType integerThousandsKeyboardType(ThousandsGroupSeparatorKey key) {
  if (key == ThousandsGroupSeparatorKey.none) {
    return TextInputType.number;
  }
  return const TextInputType.numberWithOptions(decimal: true, signed: false);
}

/// Chỉ giữ chữ số, format lại theo phân cách hàng nghìn; con trỏ cuối chuỗi.
class IntegerThousandsInputFormatter extends TextInputFormatter {
  IntegerThousandsInputFormatter({
    this.separatorKey = kAppDefaultThousandsSeparator,
  });

  final ThousandsGroupSeparatorKey separatorKey;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    var digits = digitsOnlyIntString(newValue.text);
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    while (digits.length > 1 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    try {
      final n = int.parse(digits);
      final formatted = formatIntegerWithSeparator(n, separatorKey);
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } catch (_) {
      return oldValue;
    }
  }
}
