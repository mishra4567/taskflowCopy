// services/spend/capture_payment_pattern.dart
//
// Every receipt pattern lives in THIS file, as data. When a payment app
// changes its receipt, or one particular screenshot doesn't read right,
// this is the only file to touch — the parser (payment_text_parser.dart)
// just runs whatever rules are listed here.
//
// How a receipt is read:
//  1. The scanner returns lines with their position on the image.
//  2. The parser splits them into three parts — HEADER (top third:
//     status and the big amount), DETAILS (middle: who was paid, when)
//     and FOOTER (bottom: transaction ids, bank details) — and joins
//     lines that sit on the same row ("Transaction ID" + "T2410...").
//  3. detectPaymentApp() picks the app from words/ids in the text. Rows
//     that contain a UPI id (name@bank) are left out of that check: they
//     describe the RECIPIENT ("Sent to : G Pay • ravi@oksbi"), not the
//     app the payment was made in.
//  4. For each field (amount, payee, reference) the detected app's rules
//     run first, then the generic rules as a fallback. Within a rule the
//     part named in `prefer` is searched first, but a match in any part
//     still counts — layouts differ between app versions.
//
// These patterns follow the receipt layouts these apps typically use;
// they have NOT been checked against every current app version. The
// confirm sheet's "Show scanned text" shows the raw scanned rows, which
// is what's needed to add or adjust a rule for a receipt that misses.

/// Which third of the receipt, top to bottom.
enum PaymentSection { header, details, footer }

/// Finds an amount in one line: group 1 of [pattern] is the number.
class AmountRule {
  AmountRule(String source, {this.prefer = PaymentSection.header})
    : pattern = RegExp(source, caseSensitive: false);

  final RegExp pattern;
  final PaymentSection prefer;
}

/// Finds a value that follows a label ("Paid to", "UPI transaction ID").
/// [label] matches the label line and its group 1 is whatever follows the
/// label on that same line ('' if nothing). The value is looked for
/// there first and, when [valueOnNextLine], on the line below — many
/// receipts print the label and the value on separate lines.
class LabelRule {
  LabelRule(
    String label, {
    String? value,
    String? exclude,
    this.valueOnNextLine = true,
    this.prefer = PaymentSection.details,
  }) : label = RegExp(label, caseSensitive: false),
       value = value == null ? null : RegExp(value, caseSensitive: false),
       exclude = exclude == null ? null : RegExp(exclude, caseSensitive: false);

  final RegExp label;

  /// What the value must look like (the match is used); null = the whole
  /// remaining text.
  final RegExp? value;

  /// A line matching this is skipped — e.g. GPay's own "Google
  /// transaction ID", which isn't the UPI reference.
  final RegExp? exclude;
  final bool valueOnNextLine;
  final PaymentSection prefer;
}

/// A value recognised by its shape alone, with no label (a 12-digit UPI
/// reference, PhonePe's T-prefixed transaction id). The whole match is
/// the value.
class TokenRule {
  TokenRule(String source, {this.prefer = PaymentSection.footer})
    : pattern = RegExp(source, caseSensitive: false);

  final RegExp pattern;
  final PaymentSection prefer;
}

/// Everything known about one payment app's receipt.
class PaymentAppPattern {
  PaymentAppPattern({
    required this.id,
    required this.method,
    required List<String> detect,
    this.amount = const [],
    this.payee = const [],
    this.reference = const [],
    this.referenceTokens = const [],
  }) : detect = [for (final d in detect) RegExp(d, caseSensitive: false)];

  /// Short stable name: 'phonepe', 'gpay', ...
  final String id;

  /// What the expense's "Paid with" is set to when this app is detected;
  /// null for the generic pattern.
  final String? method;

  /// Words / shapes that identify the app. The pattern with the most
  /// hits in the text wins.
  final List<RegExp> detect;

  final List<AmountRule> amount;
  final List<LabelRule> payee;
  final List<LabelRule> reference;
  final List<TokenRule> referenceTokens;
}

// ------------------------------------------------------- shared building blocks

const _currency = r'(?:₹|\b(?:rs\.?|inr))';
const _number = r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)';

// ₹250, Rs. 1,250.50, INR 99
const _amountSource = '$_currency\\s*$_number';

// The ₹ glyph is often misread by OCR (as %, ?, or dropped entirely).
// Two fallbacks, used only when no ₹/Rs/INR amount was found anywhere:
//  - a row that is only a number ("%20", "20"); capped at 9 digits so a
//    12-digit UTR or a phone number is never taken for an amount;
//  - a row that ends in "% 20" / "? 20" (name and amount read as one row).
const _loneNumberSource = r'^[^\w\s]{0,2}\s*([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)$';
const _trailingMisreadSource =
    r'[A-Za-z].*\s[%?]\s?([0-9][0-9,]{0,8}(?:\.[0-9]{1,2})?)$';

// "Paid to X", "To: X", "Sent to X". The keyword must be followed by a
// separator, whitespace or the end of the line — otherwise "Today" and
// "Total" would match the bare word "to".
const _paidToLabel =
    r'^(?:paid\s+to|payment\s+to|sent\s+to|money\s+sent\s+to|transferred\s+to|to)(?:\s*[:\-]\s*|\s+|$)(.*)$';

// "Paid ₹250 to Chai Point" on one line: group 1 is the name.
const _paidAmountToLabel =
    r'^paid\s+(?:₹|rs\.?|inr)?\s*[0-9][0-9,.]*\s+to\s+(.+)$';

// Money coming IN: "Received from X". Only these explicit phrases count —
// a bare "From" or "Credited to" row also appears on receipts for money
// that was PAID (it names your own account or the recipient's bank).
const _receivedFromLabel =
    r'^(?:received\s+from|you\s+received\s+from|money\s+received\s+from)(?:\s*[:\-]\s*|\s+|$)(.*)$';

/// Text that says the money came in rather than went out. When it
/// matches, the payment is read as "received" and the payee is taken
/// from the "Received from" row.
final RegExp receivedDirectionRe = RegExp(
  r'\b(?:received\s+from|you\s+received)\b',
  caseSensitive: false,
);

/// Payee rules used first for a receipt that says money was received.
/// (Written from the usual wording, not checked against real received
/// receipts — add one and adjust if it misses.)
final List<LabelRule> receivedPayeeRules = [
  LabelRule(_receivedFromLabel, prefer: PaymentSection.header),
];

const _upiRefLabel =
    r'upi\s*(?:transaction|txn|ref(?:erence)?)\s*(?:id|no\.?|number)?\s*[:\-]?\s*(.*)$';
const _utrLabel = r'\butr\b(?:\s*(?:no\.?|number))?\s*[:\-]?\s*(.*)$';
const _txnIdLabel =
    r'(?:transaction|txn|reference|ref)\s*(?:id|no\.?|number)\s*[:\-]?\s*(.*)$';

const _digits12 = r'(?<!\d)\d{12}(?!\d)';
const _alnumRef = r'[A-Za-z0-9]{8,}';
const _longRef = r'[A-Za-z0-9]{10,}';

// ------------------------------------------------------------------ patterns

/// Used for every receipt, after the detected app's own rules.
final PaymentAppPattern genericPaymentPattern = PaymentAppPattern(
  id: 'generic',
  method: null,
  detect: const [],
  amount: [
    AmountRule(_amountSource),
    AmountRule(_loneNumberSource),
    AmountRule(_trailingMisreadSource),
  ],
  payee: [
    LabelRule(_paidAmountToLabel, valueOnNextLine: false),
    LabelRule(_paidToLabel, prefer: PaymentSection.header),
  ],
  reference: [
    LabelRule(_upiRefLabel, value: _alnumRef, exclude: r'google'),
    LabelRule(_utrLabel, value: _digits12),
    LabelRule(_txnIdLabel, value: _alnumRef, exclude: r'google'),
  ],
  referenceTokens: [TokenRule(_digits12)],
);

final PaymentAppPattern phonePePattern = PaymentAppPattern(
  id: 'phonepe',
  method: 'PhonePe',
  // The PhonePe header is only a logo (no "PhonePe" text), so the app is
  // also recognised by its own T-prefixed transaction id and its
  // "Transfer Details" section.
  detect: [r'phone\s*pe', r'\bT\d{15,}\b', r'transfer\s+details'],
  amount: [AmountRule(_amountSource)],
  payee: [
    LabelRule(_paidAmountToLabel, valueOnNextLine: false),
    LabelRule(_paidToLabel, prefer: PaymentSection.header),
  ],
  // UTR (12 digits) identifies the payment across apps and the bank, so
  // it's preferred over PhonePe's own T-prefixed transaction id.
  reference: [
    LabelRule(_utrLabel, value: _digits12, prefer: PaymentSection.footer),
    LabelRule(_txnIdLabel, value: _longRef, prefer: PaymentSection.footer),
  ],
  referenceTokens: [TokenRule(_digits12), TokenRule(r'\bT\d{15,}\b')],
);

final PaymentAppPattern gPayPattern = PaymentAppPattern(
  id: 'gpay',
  method: 'GPay',
  detect: [r'google\s*pay', r'\bg\s*pay\b', r'google\s+transaction\s+id'],
  amount: [AmountRule(_amountSource)],
  payee: [
    LabelRule(_paidToLabel, prefer: PaymentSection.header),
    LabelRule(_paidAmountToLabel, valueOnNextLine: false),
  ],
  // "UPI transaction ID" is the real reference; the "Google transaction
  // ID" printed beside it is skipped.
  reference: [
    LabelRule(
      _upiRefLabel,
      value: _alnumRef,
      exclude: r'google',
      prefer: PaymentSection.footer,
    ),
  ],
  referenceTokens: [TokenRule(_digits12)],
);

final PaymentAppPattern paytmPattern = PaymentAppPattern(
  id: 'paytm',
  method: 'Paytm',
  detect: [r'paytm'],
  amount: [AmountRule(_amountSource)],
  payee: [
    LabelRule(_paidAmountToLabel, valueOnNextLine: false),
    LabelRule(_paidToLabel, prefer: PaymentSection.header),
  ],
  reference: [
    LabelRule(_upiRefLabel, value: _alnumRef, prefer: PaymentSection.footer),
    LabelRule(_utrLabel, value: _digits12, prefer: PaymentSection.footer),
  ],
  referenceTokens: [TokenRule(_digits12)],
);

final PaymentAppPattern bhimPattern = PaymentAppPattern(
  id: 'bhim',
  method: 'BHIM',
  detect: [r'\bbhim\b'],
  amount: [AmountRule(_amountSource)],
  payee: [LabelRule(_paidToLabel, prefer: PaymentSection.header)],
  reference: [
    LabelRule(_txnIdLabel, value: _alnumRef, prefer: PaymentSection.footer),
    LabelRule(_upiRefLabel, value: _alnumRef, prefer: PaymentSection.footer),
  ],
  referenceTokens: [TokenRule(_digits12)],
);

final PaymentAppPattern amazonPayPattern = PaymentAppPattern(
  id: 'amazonpay',
  method: 'Other',
  detect: [r'amazon\s*pay'],
  amount: [AmountRule(_amountSource)],
  payee: [
    LabelRule(_paidAmountToLabel, valueOnNextLine: false),
    LabelRule(_paidToLabel, prefer: PaymentSection.header),
  ],
  reference: [
    LabelRule(_txnIdLabel, value: _longRef, prefer: PaymentSection.footer),
  ],
  referenceTokens: [TokenRule(_digits12)],
);

/// Add a new app's pattern here (and detect rules in it) to teach the
/// scanner another receipt. Order only matters for ties.
final List<PaymentAppPattern> paymentAppPatterns = [
  phonePePattern,
  gPayPattern,
  paytmPattern,
  bhimPattern,
  amazonPayPattern,
];

/// The pattern whose detect rules hit the text most, or null when none
/// of them hit (the generic pattern is used on its own then).
PaymentAppPattern? detectPaymentApp(String text) {
  PaymentAppPattern? best;
  var bestScore = 0;
  for (final pattern in paymentAppPatterns) {
    final score = pattern.detect.where((r) => r.hasMatch(text)).length;
    if (score > bestScore) {
      best = pattern;
      bestScore = score;
    }
  }
  return best;
}