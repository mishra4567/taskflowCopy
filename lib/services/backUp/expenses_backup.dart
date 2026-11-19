// services/expenses_backup
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:taskflow/data/app_database.dart';

// Expenses as plain maps for taskflow_backup.json's "expenses" list.
//
// Row ids are deliberately NOT exported: they're autoincrement numbers
// that mean nothing on another phone, and restore assigns fresh ones
// (so restoring onto a phone that already has payments can't hit a
// primary-key conflict).
Future<List<Map<String, dynamic>>> exportExpenses() async {
  final rows = await AppDatabase.instance.getAllExpenses();
  return [
    for (final e in rows)
      {
        'amountPaise': e.amountPaise,
        'paidAt': e.paidAt.millisecondsSinceEpoch,
        'payee': e.payee,
        'category': e.category,
        'note': e.note,
        'method': e.method,
        'upiRef': e.upiRef,
        'source': e.source,
        'direction': e.direction,
        'createdAt': e.createdAt.millisecondsSinceEpoch,
      },
  ];
}

// Restores the "expenses" list from a decoded backup. [raw] is
// `data['expenses']`; null means an older backup with no expenses
// section. Returns how many payments were actually added.
//
// Merges, never overwrites:
// - A payment with a UPI reference is skipped if that reference is
//   already saved (same reference = same payment).
// - A payment without one (cash, typed by hand) is skipped if the phone
//   already has one with the same amount, time, payee and direction.
//   Matching is by COUNT: if the backup holds two identical payments
//   and the phone holds one, one is added — so restoring the same file
//   twice adds nothing, but two genuinely identical payments survive.
// Must run inside BackupService.restore's transaction.
Future<int> restoreExpenses(Object? raw) async {
  if (raw == null) return 0;
  if (raw is! List) {
    debugPrint('restoreExpenses: expected a list, got ${raw.runtimeType}');
    return 0;
  }

  final db = AppDatabase.instance;
  final existing = await db.getAllExpenses();

  final knownRefs = <String>{
    for (final e in existing)
      if (e.upiRef != null) e.upiRef!,
  };
  final unreferencedLeft = <String, int>{};
  for (final e in existing) {
    if (e.upiRef == null) {
      final key = _signature(e.amountPaise, e.paidAt, e.payee, e.direction);
      unreferencedLeft[key] = (unreferencedLeft[key] ?? 0) + 1;
    }
  }

  var added = 0;
  var alreadyPresent = 0;
  var unreadable = 0;

  for (final item in raw) {
    if (item is! Map) {
      unreadable++;
      continue;
    }

    final amount = item['amountPaise'];
    final paidAt = _asDate(item['paidAt']);
    // Same rule as the add sheet: an expense needs a positive amount and
    // a date. Anything else in the file can't be a real payment.
    if (amount is! int || amount <= 0 || paidAt == null) {
      unreadable++;
      continue;
    }

    final payee = _string(item['payee'], '');
    final category = _string(item['category'], 'Other');
    final note = _string(item['note'], '');
    final method = _string(item['method'], 'Other');
    final source = item['source'] == 'screenshot' ? 'screenshot' : 'manual';
    final direction = item['direction'] == 'received' ? 'received' : 'paid';
    final createdAt = _asDate(item['createdAt']);

    final rawRef = item['upiRef'];
    final upiRef = rawRef is String && rawRef.trim().isNotEmpty
        ? rawRef.trim()
        : null;

    if (upiRef != null) {
      if (knownRefs.contains(upiRef)) {
        alreadyPresent++;
        continue;
      }
    } else {
      final key = _signature(amount, paidAt, payee, direction);
      final left = unreferencedLeft[key] ?? 0;
      if (left > 0) {
        unreferencedLeft[key] = left - 1;
        alreadyPresent++;
        continue;
      }
    }

    await db.insertExpense(
      ExpensesCompanion.insert(
        amountPaise: amount,
        paidAt: paidAt,
        payee: Value(payee),
        category: Value(category),
        note: Value(note),
        method: Value(method),
        upiRef: Value(upiRef),
        source: Value(source),
        direction: Value(direction),
        // Keep the original "saved on" time when the file has one.
        createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
      ),
    );
    if (upiRef != null) knownRefs.add(upiRef);
    added++;
  }

  debugPrint(
    'restoreExpenses: ${raw.length} in backup, $added added, '
    '$alreadyPresent already present, $unreadable unreadable.',
  );
  return added;
}

// Seconds, not milliseconds: the database stores DateTime as whole
// seconds, so a payment read back from it has no milliseconds, and the
// backup's value must be compared at the same precision.
String _signature(int amountPaise, DateTime paidAt, String payee, String dir) =>
    '$amountPaise|${paidAt.millisecondsSinceEpoch ~/ 1000}|$payee|$dir';

String _string(Object? value, String fallback) =>
    value is String ? value : fallback;

DateTime? _asDate(Object? value) {
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  return null;
}
