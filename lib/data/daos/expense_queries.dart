import 'package:drift/drift.dart' show OrderingTerm;

import '../app_database.dart';

/// Expense queries, kept in their own file like TodoQueries.
extension ExpenseQueries on AppDatabase {
  /// Live list, newest payment first. Emits again on every insert,
  /// edit or delete, so a screen using it never needs a manual refresh.
  Stream<List<Expense>> watchExpenses() {
    return (select(expenses)..orderBy([
          (e) => OrderingTerm.desc(e.paidAt),
          (e) => OrderingTerm.desc(e.id),
        ]))
        .watch();
  }

  Future<List<Expense>> getAllExpenses() {
    return (select(expenses)..orderBy([(e) => OrderingTerm.asc(e.id)])).get();
  }

  /// Insert a new expense. Build the companion with
  /// `ExpensesCompanion.insert(...)`. A backup restore can pass the
  /// original `createdAt` inside it; otherwise the column default (now)
  /// applies.
  Future<int> insertExpense(ExpensesCompanion entry) {
    return into(expenses).insert(entry);
  }

  /// Writes only the fields present in [changes]; absent fields (like
  /// upiRef and source) are left untouched.
  Future<void> updateExpense(int id, ExpensesCompanion changes) {
    return (update(expenses)..where((e) => e.id.equals(id))).write(changes);
  }

  Future<void> deleteExpense(int id) {
    return (delete(expenses)..where((e) => e.id.equals(id))).go();
  }

  /// The expense already saved with this UPI reference, if any. The
  /// caller compares its id against the row being edited.
  Future<Expense?> findExpenseByUpiRef(String ref) {
    return (select(expenses)
          ..where((e) => e.upiRef.equals(ref))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<Expense?> getExpenseById(int id) {
    return (select(expenses)..where((e) => e.id.equals(id))).getSingleOrNull();
  }
}
