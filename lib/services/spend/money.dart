// services/money

/// Formats whole paise as rupees with Indian digit grouping:
/// 25000 -> ₹250, 12345678 -> ₹1,23,456.78, -5050 -> -₹50.50.
///
/// Money in this app is always an int number of paise (₹12.50 = 1250),
/// never a double, so adding up a month of expenses is exact.
String formatRupees(int paise) {
  final negative = paise < 0;
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final rem = abs % 100;
  final fraction = rem == 0 ? '' : '.${rem.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}₹${_groupIndian(rupees.toString())}$fraction';
}

/// 1234567 -> "12,34,567": the last three digits, then pairs.
String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  return '${groups.join(',')},$lastThree';
}

/// Parses what a person types into an amount field — "250", "1,250.5",
/// "₹99.99", "Rs 40" — into whole paise. Null if it isn't a plain
/// amount (no digits, more than two decimals, a stray letter, ...).
int? parseRupeesToPaise(String input) {
  final cleaned = input.replaceAll(
    RegExp(r'[₹,\s]|rs\.?|inr', caseSensitive: false),
    '',
  );
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(cleaned);
  if (match == null) return null;
  final rupeesText = match.group(1)!;
  if (rupeesText.length > 11) return null; // far beyond any real payment
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  return int.parse(rupeesText) * 100 +
      (fraction.isEmpty ? 0 : int.parse(fraction));
}

/// Paise back to what the amount field should show: 25000 -> "250",
/// 9950 -> "99.50". No ₹ and no grouping, so it round-trips through
/// [parseRupeesToPaise].
String paiseToInput(int paise) {
  final rupees = paise ~/ 100;
  final rem = paise % 100;
  return rem == 0 ? '$rupees' : '$rupees.${rem.toString().padLeft(2, '0')}';
}
