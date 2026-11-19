// services/receipt_layout
//
// Turns OCR output into what capture_payment_pattern.dart's rules read:
//  1. Words (each with its position on the image) are regrouped into ROWS
//     by vertical overlap, left to right. This is why "Transaction ID"
//     and its value end up on one row even when the scanner put them in
//     different blocks.
//  2. Rows are split into three sections by height: header (top third),
//     details (middle), footer (bottom).
// Pure Dart, no plugin, so it can be tested on its own.
import 'capture_payment_pattern.dart';

// One recognised word and where it sits on the image.
class PositionedWord {
  const PositionedWord(
    this.text, {
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get height => bottom - top;
}

// One visual row of the receipt.
class ReceiptRow {
  const ReceiptRow({
    required this.text,
    required this.top,
    required this.bottom,
  });

  final String text;
  final double top;
  final double bottom;

  double get centerY => (top + bottom) / 2;
}

class _RowBuilder {
  _RowBuilder(PositionedWord first)
    : top = first.top,
      bottom = first.bottom,
      words = [first];

  double top;
  double bottom;
  final List<PositionedWord> words;

  // Same row when the vertical overlap is more than half of the smaller
  // of the two heights — so a small label beside a big amount still joins.
  bool accepts(PositionedWord w) {
    final overlap =
        (w.bottom < bottom ? w.bottom : bottom) - (w.top > top ? w.top : top);
    final rowHeight = bottom - top;
    final smaller = w.height < rowHeight ? w.height : rowHeight;
    return overlap > smaller * 0.5;
  }

  void add(PositionedWord w) {
    words.add(w);
    if (w.top < top) top = w.top;
    if (w.bottom > bottom) bottom = w.bottom;
  }
}

// Rebuilds rows (top to bottom) from loose words (any order).
List<ReceiptRow> groupWordsIntoRows(List<PositionedWord> words) {
  final usable =
      words.where((w) => w.text.trim().isNotEmpty && w.height > 0).toList()
        ..sort(
          (a, b) => ((a.top + a.bottom) / 2).compareTo((b.top + b.bottom) / 2),
        );

  final builders = <_RowBuilder>[];
  for (final word in usable) {
    if (builders.isNotEmpty && builders.last.accepts(word)) {
      builders.last.add(word);
    } else {
      builders.add(_RowBuilder(word));
    }
  }

  final rows = [
    for (final b in builders)
      ReceiptRow(
        text: (b.words..sort((x, y) => x.left.compareTo(y.left)))
            .map((w) => w.text.trim())
            .join(' '),
        top: b.top,
        bottom: b.bottom,
      ),
  ]..sort((a, b) => a.top.compareTo(b.top));
  return rows;
}

// Rows for plain text with no positions (text shared as text, tests):
// each line becomes one evenly spaced row.
List<ReceiptRow> rowsFromPlainText(String text) {
  final lines = text
      .replaceAll('\r', '')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  return [
    for (var i = 0; i < lines.length; i++)
      ReceiptRow(text: lines[i], top: i * 10.0, bottom: i * 10.0 + 8),
  ];
}

// Which third each row is in (parallel to [rows]). The thirds are of
// the height the text actually covers, not of the whole image, so empty
// space above or below the receipt doesn't skew them.
List<PaymentSection> sectionsFor(List<ReceiptRow> rows) {
  if (rows.isEmpty) return const [];
  var minTop = rows.first.top;
  var maxBottom = rows.first.bottom;
  for (final r in rows) {
    if (r.top < minTop) minTop = r.top;
    if (r.bottom > maxBottom) maxBottom = r.bottom;
  }
  final span = maxBottom - minTop;
  if (span <= 0) {
    return [for (final _ in rows) PaymentSection.details];
  }
  final third = span / 3;
  return [
    for (final r in rows)
      r.centerY < minTop + third
          ? PaymentSection.header
          : r.centerY < minTop + 2 * third
          ? PaymentSection.details
          : PaymentSection.footer,
  ];
}

// Rows plus their sections, with the lookups the parser needs.
class ReceiptDoc {
  ReceiptDoc(List<ReceiptRow> rows)
    : rows = List.unmodifiable(rows),
      sections = sectionsFor(rows);

  final List<ReceiptRow> rows;
  final List<PaymentSection> sections;

  String get fullText => rows.map((r) => r.text).join('\n');

  // Row indexes in the order a rule should search them: its preferred
  // section first, then the rest. A match anywhere still counts —
  // layouts differ between app versions.
  List<int> searchOrder(PaymentSection prefer) {
    final order = <PaymentSection>[
      prefer,
      ...PaymentSection.values.where((s) => s != prefer),
    ];
    return [
      for (final section in order)
        for (var i = 0; i < rows.length; i++)
          if (sections[i] == section) i,
    ];
  }

  // One row per line, tagged H / D / F — what "Show what was read"
  // displays, so a receipt that misses can be matched to a rule.
  String debugDump() => [
    for (var i = 0; i < rows.length; i++)
      '${_tag(sections[i])} | ${rows[i].text}',
  ].join('\n');

  static String _tag(PaymentSection s) => switch (s) {
    PaymentSection.header => 'H',
    PaymentSection.details => 'D',
    PaymentSection.footer => 'F',
  };
}
