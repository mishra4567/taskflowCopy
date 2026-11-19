// services/spend/payment_text_parser.dart
//
// Runs the rules in capture_payment_pattern.dart over a scanned receipt.
// For each field the detected app's rules run first, then the generic
// ones; within a rule the preferred section is searched first. All the
// patterns live in capture_payment_pattern.dart — this file only runs them.
import 'capture_payment_pattern.dart';
import 'money.dart';
import 'receipt_layout.dart';

// What could be read out of a payment receipt. Every field is nullable:
// OCR text is messy, so this only fills in what it is reasonably sure of.
class ParsedPayment {
  const ParsedPayment({
    this.amountPaise,
    this.payee,
    this.paidAt,
    this.upiRef,
    this.method,
    this.looksUnsuccessful = false,
    this.direction = 'paid',
  });

  // 'paid' (money went out — the default) or 'received' (the receipt
  // says "Received from ..."). For a received payment, [payee] is the
  // person who paid you.
  final String direction;

  final int? amountPaise;
  final String? payee;
  final DateTime? paidAt;

  // The UPI transaction / UTR number — the same on every copy of the
  // same payment, so it's what stops one screenshot being saved twice.
  final String? upiRef;

  // "GPay", "PhonePe", "Paytm", "BHIM" or "Other" when the app is known.
  final String? method;

  // The text mentions failed / pending / declined / refunded.
  final bool looksUnsuccessful;

  bool get isEmpty =>
      amountPaise == null &&
      payee == null &&
      paidAt == null &&
      upiRef == null &&
      method == null;

  // Safe to save without asking: amount, payee and a reference to guard
  // against duplicates are all present, the receipt doesn't look failed,
  // and the payee looks like a name (a UPI id, or text with no digits).
  // A payee with digits in it usually means an amount was read into the
  // name by mistake, so that goes to the confirm sheet instead. (A
  // missing date is fine — a payment shared straight after paying is
  // saved as "now".)
  bool get isConfident =>
      amountPaise != null &&
      payee != null &&
      upiRef != null &&
      !looksUnsuccessful &&
      (payee!.contains('@') || !RegExp(r'\d').hasMatch(payee!));
}

class PaymentTextParser {
  PaymentTextParser._();

  // Plain text with no positions (text shared as text, tests).
  static ParsedPayment parse(String raw) => parseRows(rowsFromPlainText(raw));

  static ParsedPayment parseRows(List<ReceiptRow> rows) {
    if (rows.isEmpty) return const ParsedPayment();
    final doc = ReceiptDoc(rows);
    final fullText = doc.fullText;

    // A row with a UPI id describes the RECIPIENT ("Sent to : G Pay •
    // ravi@oksbi"), so it says nothing about which app made the payment.
    final ownText = rows
        .where((r) => !r.text.contains('@'))
        .map((r) => r.text)
        .join('\n');
    final app = detectPaymentApp(ownText);
    final patterns = <PaymentAppPattern>[?app, genericPaymentPattern];
    final received = receivedDirectionRe.hasMatch(fullText);

    return ParsedPayment(
      amountPaise: _amount(patterns, doc),
      payee: _payee(patterns, doc, received: received),
      paidAt: _paidAt(fullText),
      upiRef: _reference(patterns, doc),
      method: app?.method,
      looksUnsuccessful: _failureRe.hasMatch(fullText),
      direction: received ? 'received' : 'paid',
    );
  }

  // ---------------------------------------------------------------- amount

  static int? _amount(List<PaymentAppPattern> patterns, ReceiptDoc doc) {
    for (final pattern in patterns) {
      for (final rule in pattern.amount) {
        for (final i in doc.searchOrder(rule.prefer)) {
          final m = rule.pattern.firstMatch(doc.rows[i].text);
          if (m == null || m.groupCount < 1) continue;
          final paise = parseRupeesToPaise(m.group(1) ?? '');
          if (paise != null && paise > 0) return paise;
        }
      }
    }
    return null;
  }

  // ----------------------------------------------------------------- payee

  static String? _payee(
    List<PaymentAppPattern> patterns,
    ReceiptDoc doc, {
    bool received = false,
  }) {
    // Money received: the name after "Received from" comes first.
    if (received) {
      final name = _payeeFromRules(receivedPayeeRules, doc);
      if (name != null) return name;
    }
    for (final pattern in patterns) {
      final name = _payeeFromRules(pattern.payee, doc);
      if (name != null) return name;
    }
    return null;
  }

  static String? _payeeFromRules(List<LabelRule> rules, ReceiptDoc doc) {
    for (final rule in rules) {
      for (final i in doc.searchOrder(rule.prefer)) {
        final text = doc.rows[i].text;
        if (rule.exclude?.hasMatch(text) ?? false) continue;
        final m = rule.label.firstMatch(text);
        if (m == null) continue;

        var name = (m.groupCount >= 1 ? m.group(1) : null)?.trim() ?? '';
        // "Paid to" alone on its row: the name is on the next one
        // (which may be in the next section down).
        if (name.isEmpty && rule.valueOnNextLine && i + 1 < doc.rows.length) {
          name = doc.rows[i + 1].text;
        }
        final cleaned = _cleanPayee(name);
        if (cleaned != null) return cleaned;
      }
    }
    return null;
  }

  // Rows that follow a "to" label but are not a person or shop.
  static final _notAPayeeRe = RegExp(
    r'^(?:bank\b|account\b|a/c\b|your\b|upi\b|transaction\b|txn\b|status\b|'
    r'details\b|completed\b|successful\b|payment\b|paid\b|sent\b|from\b|'
    r'[x*•.]{2,})',
    caseSensitive: false,
  );

  // An amount stuck on the end of a name, because the name and the
  // right-aligned amount were read as one row ("MONALISHA DAS MANNA ₹20").
  static final _trailingAmountRe = RegExp(
    r'\s*(?:₹|\brs\.?|\binr)\s*[0-9][0-9,]*(?:\.[0-9]{1,2})?$',
    caseSensitive: false,
  );

  static String? _cleanPayee(String input) {
    var name = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    name = name.replaceAll(_trailingAmountRe, '');
    name = name.replaceAll(RegExp(r'[\s:\-,.]+$'), '');
    if (name.length < 2 || name.length > 60) return null;
    if (!RegExp(r'[A-Za-z]').hasMatch(name)) return null; // numbers only
    if (_notAPayeeRe.hasMatch(name)) return null;
    if (_dayMonthYearRe.hasMatch(name) ||
        _monthDayYearRe.hasMatch(name) ||
        _numericDateRe.hasMatch(name) ||
        RegExp(r'\b\d{1,2}:\d{2}\b').hasMatch(name)) {
      return null; // a date or time row, not a name
    }
    // Receipts print names in capitals ("RAVI KUMAR"); read them as
    // names. A UPI id (ravi@okhdfc) is left exactly as written.
    if (name == name.toUpperCase() && !name.contains('@')) {
      name = name
          .split(' ')
          .map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}')
          .join(' ');
    }
    return name;
  }

  // ------------------------------------------------------------- reference

  static String? _reference(List<PaymentAppPattern> patterns, ReceiptDoc doc) {
    for (final pattern in patterns) {
      for (final rule in pattern.reference) {
        for (final i in doc.searchOrder(rule.prefer)) {
          final text = doc.rows[i].text;
          if (rule.exclude?.hasMatch(text) ?? false) continue;
          final m = rule.label.firstMatch(text);
          if (m == null) continue;

          final rest = (m.groupCount >= 1 ? m.group(1) : null) ?? '';
          var token = _pickValue(rule, rest);
          // Label and number are often on separate rows.
          if (token == null &&
              rule.valueOnNextLine &&
              i + 1 < doc.rows.length) {
            final next = doc.rows[i + 1].text;
            if (!(rule.exclude?.hasMatch(next) ?? false)) {
              token = _pickValue(rule, next);
            }
          }
          if (token != null && _looksLikeRef(token)) return token.toUpperCase();
        }
      }
      for (final rule in pattern.referenceTokens) {
        for (final i in doc.searchOrder(rule.prefer)) {
          final m = rule.pattern.firstMatch(doc.rows[i].text);
          if (m != null) return m.group(0)!.toUpperCase();
        }
      }
    }
    return null;
  }

  static String? _pickValue(LabelRule rule, String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final value = rule.value;
    if (value == null) return t;
    return value.firstMatch(t)?.group(0);
  }

  // A real reference is mostly digits. This rejects ordinary words
  // ("Successful", "Completed") picked up from the row below a label.
  static bool _looksLikeRef(String token) =>
      RegExp(r'\d').allMatches(token).length >= 6;

  // ------------------------------------------------------------- date/time

  static const _monthPattern =
      r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?';
  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  // 9 Oct 2026 / 09 October, 2026
  static final _dayMonthYearRe = RegExp(
    '\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+$_monthPattern,?\\s+(\\d{4})\\b',
    caseSensitive: false,
  );
  // Oct 9, 2026 / October 09 2026
  static final _monthDayYearRe = RegExp(
    '\\b$_monthPattern\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4})\\b',
    caseSensitive: false,
  );
  // 09/10/2026, 09-10-2026 — day first, as in India.
  static final _numericDateRe = RegExp(
    r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})\b',
  );
  static final _timeRe = RegExp(
    r'\b(\d{1,2}):(\d{2})(?::\d{2})?\s*([ap]\.?m\.?)?',
    caseSensitive: false,
  );

  static DateTime? _paidAt(String text) {
    ({int start, int end, int year, int month, int day})? best;

    void consider(RegExpMatch? m, int year, int month, int day) {
      if (m == null) return;
      if (year < 2000 || year > 2100) return;
      if (month < 1 || month > 12 || day < 1 || day > 31) return;
      // DateTime silently rolls 31 Feb into March — reject it instead.
      final check = DateTime(year, month, day);
      if (check.month != month || check.day != day) return;
      if (best == null || m.start < best!.start) {
        best = (start: m.start, end: m.end, year: year, month: month, day: day);
      }
    }

    final dmy = _dayMonthYearRe.firstMatch(text);
    if (dmy != null) {
      consider(
        dmy,
        int.parse(dmy.group(3)!),
        _months[dmy.group(2)!.toLowerCase()]!,
        int.parse(dmy.group(1)!),
      );
    }
    final mdy = _monthDayYearRe.firstMatch(text);
    if (mdy != null) {
      consider(
        mdy,
        int.parse(mdy.group(3)!),
        _months[mdy.group(1)!.toLowerCase()]!,
        int.parse(mdy.group(2)!),
      );
    }
    final numeric = _numericDateRe.firstMatch(text);
    if (numeric != null) {
      consider(
        numeric,
        int.parse(numeric.group(3)!),
        int.parse(numeric.group(2)!),
        int.parse(numeric.group(1)!),
      );
    }

    final found = best;
    if (found == null) return null;

    // The time sits right after the date ("9 Oct 2026, 3:15 pm") or just
    // before it ("3:15 PM, 9 Oct 2026" / "09:19 am on 16 Oct 2026").
    final afterEnd = found.end + 30 > text.length
        ? text.length
        : found.end + 30;
    var time = _timeRe.firstMatch(text.substring(found.end, afterEnd));
    if (time == null) {
      final beforeStart = found.start - 25 < 0 ? 0 : found.start - 25;
      final matches = _timeRe
          .allMatches(text.substring(beforeStart, found.start))
          .toList();
      if (matches.isNotEmpty) time = matches.last;
    }

    var hour = 0;
    var minute = 0;
    if (time != null) {
      hour = int.parse(time.group(1)!);
      minute = int.parse(time.group(2)!);
      final meridiem = time.group(3)?.toLowerCase().replaceAll('.', '');
      if (meridiem == 'pm' && hour < 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
      if (hour > 23 || minute > 59) {
        hour = 0;
        minute = 0;
      }
    }
    return DateTime(found.year, found.month, found.day, hour, minute);
  }

  // ---------------------------------------------------------------- status

  static final _failureRe = RegExp(
    r'\b(?:failed|failure|declined|unsuccessful|pending|processing|reversed|refunded)\b',
    caseSensitive: false,
  );
}
