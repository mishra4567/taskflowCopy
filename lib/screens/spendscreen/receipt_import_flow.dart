// screens/spendscreen/receipt_import_flow.dart
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:taskflow/data/app_database.dart';
import 'package:taskflow/services/spend/expense_refresh_bus.dart';
import 'package:taskflow/services/spend/money.dart';
import 'package:taskflow/services/spend/payment_text_parser.dart';
import 'package:taskflow/services/spend/receipt_layout.dart';
import 'package:taskflow/services/spend/receipt_scanner.dart';
import 'expense_sheet.dart';

// true: a payment the parser is confident about (amount, payee and UPI
// reference all read, not a failed receipt) is saved straight away, with
// an Edit button on the snackbar. false: the confirm sheet always opens.
const autoSaveConfidentPayments = true;

// Reads a payment screenshot and either saves it or opens the confirm
// sheet, pre-filled. Used by both "Scan screenshot" on the Spending
// screen and images shared into the app from GPay / PhonePe / etc.
// A receipt that says "Received from ..." is saved as money received.
//
// Set [deleteWhenDone] only for a file this app made itself (a shared
// image copied into the cache) — never for a file the person picked,
// which on some platforms is their original.
Future<void> importPaymentImage(
  BuildContext context,
  String imagePath, {
  required bool deleteWhenDone,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  // ignore: unawaited_futures
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  ScannedReceipt? scan;
  try {
    scan = await scanReceiptImage(imagePath);
  } catch (_) {
    scan = null;
  } finally {
    navigator.pop();
    if (deleteWhenDone) {
      try {
        await File(imagePath).delete();
      } catch (_) {}
    }
  }
  if (!context.mounted) return;

  if (scan == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Couldn't read that image — add the payment by hand."),
      ),
    );
    await showExpenseSheet(context, onSaved: ExpenseRefreshBus.notify);
    return;
  }

  final parsed = PaymentTextParser.parseRows(scan.rows);
  final dump = ReceiptDoc(scan.rows).debugDump();

  // The same UPI reference is the same payment: never save it twice.
  final ref = parsed.upiRef;
  if (ref != null) {
    final existing = await AppDatabase.instance.findExpenseByUpiRef(ref);
    if (!context.mounted) return;
    if (existing != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Already saved: ${existing.payee} · '
            '${formatRupees(existing.amountPaise)}',
          ),
        ),
      );
      return;
    }
  }

  if (autoSaveConfidentPayments && parsed.isConfident) {
    final saved = await _autoSave(parsed);
    if (!context.mounted) return;
    if (saved != null) {
      final received = saved.direction == directionReceived;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              received
                  ? 'Received ${formatRupees(saved.amountPaise)} from '
                        '${saved.payee}'
                  : 'Saved ${formatRupees(saved.amountPaise)} · ${saved.payee}',
            ),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Edit',
              onPressed: () {
                if (!context.mounted) return;
                showExpenseSheet(
                  context,
                  existing: saved,
                  onSaved: ExpenseRefreshBus.notify,
                  onDelete: () async {
                    await AppDatabase.instance.deleteExpense(saved.id);
                    ExpenseRefreshBus.notify();
                  },
                );
              },
            ),
          ),
        );
      return;
    }
    // Saving failed (e.g. a race on the same reference): fall through
    // to the sheet, which reports it.
  }

  await showExpenseSheet(
    context,
    prefill: parsed,
    // Nothing read at all means the person is typing it in: that's manual.
    source: parsed.isEmpty ? 'manual' : 'screenshot',
    scanText: dump,
    onSaved: ExpenseRefreshBus.notify,
  );
}

Future<Expense?> _autoSave(ParsedPayment p) async {
  final db = AppDatabase.instance;
  final int id;
  try {
    id = await db.insertExpense(
      ExpensesCompanion.insert(
        amountPaise: p.amountPaise!,
        paidAt: p.paidAt ?? DateTime.now(),
        payee: Value(p.payee!),
        method: Value(p.method ?? 'Other'),
        direction: Value(p.direction),
        upiRef: Value(p.upiRef),
        source: const Value('screenshot'),
      ),
    );
  } catch (_) {
    return null; // nothing was saved: the caller opens the sheet instead
  }
  ExpenseRefreshBus.notify();
  try {
    return await db.getExpenseById(id);
  } catch (_) {
    return null;
  }
}
