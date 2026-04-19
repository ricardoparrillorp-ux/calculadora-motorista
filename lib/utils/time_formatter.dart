import 'package:flutter/services.dart';

class TimeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(
          text: '', selection: const TextSelection.collapsed(offset: 0));
    }
    final d = digits.length > 4 ? digits.substring(0, 4) : digits;
    final formatted =
        d.length <= 2 ? d : '${d.substring(0, 2)}:${d.substring(2)}';
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}
