// data/tables/expenses_table.dart
import 'package:drift/drift.dart';

// One payment. Money is stored as a whole number of paise (₹12.50 =
// 1250), never a double, so adding up a month of expenses is exact.
//
// [upiRef] is the UPI transaction / UTR number printed on the receipt.
// It is the same on every copy of the same payment, so it's what stops
// one screenshot being saved twice. Null for cash and manual entries.
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  // Money is stored in paise (integer) to avoid floating-point errors.
  IntColumn get amountPaise => integer()();
  DateTimeColumn get paidAt => dateTime()();

  TextColumn get payee => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant('Other'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get method => text().withDefault(const Constant('Other'))();

  // UPI reference; null for manual or cash payments.
  TextColumn get upiRef => text().nullable()();

  // Where the row came from: 'manual' or 'screenshot'.
  TextColumn get source => text().withDefault(const Constant('manual'))();

  // 'paid' (money went out) or 'received' (money came in).
  TextColumn get direction => text().withDefault(const Constant('paid'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
