// data/app_database
//
// Drift is the 2026-recommended default local database for Flutter: it's
// SQL-backed (built on SQLite, the most battle-tested embedded database
// there is), actively maintained, type-safe, reactive, and runs on every
// platform this app targets, including web. Hive and Isar were considered
// and rejected — both were abandoned by their original authors and are now
// community-maintained forks, which is a liability for a database (the
// stickiest, hardest-to-migrate-away-from decision in a codebase).
//
// Tables live one-per-file under data/tables/. Query methods live
// one-concern-per-file under data/daos/, added onto AppDatabase via
// `extension ... on AppDatabase` rather than piled into this class
// directly. This file just wires everything together and owns the
// connection — it re-exports the tables and daos, so anywhere that
// already does `import '../data/app_database.dart'` keeps working
// unchanged.
//
// IMPORTANT — one manual step required whenever a table changes:
// Drift generates a companion `app_database.g.dart` from the annotation
// below via build_runner. Run this once (and again after changing any
// table):
//
//   dart run build_runner build --delete-conflicting-outputs
//
// That generated file defines `_$AppDatabase`, which this file extends.
// Nothing here will compile until you've run that command.
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/todos_table.dart';
import 'tables/subtasks_table.dart';
import 'tables/extensions_table.dart';
import 'tables/extension_records_table.dart';
import 'tables/contacts_table.dart';
// Imported (not just exported below) because the migration calls
// migrateLegacyContacts(), an extension method defined in this file.
import 'daos/contact_queries.dart';

export 'tables/todos_table.dart';
export 'tables/subtasks_table.dart';
export 'tables/extensions_table.dart';
export 'tables/extension_records_table.dart';
export 'tables/contacts_table.dart';
export 'daos/todo_queries.dart';
export 'daos/extension_queries.dart';
export 'daos/contact_queries.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Todos, Subtasks, Extensions, ExtensionRecords, Contacts],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  /// Constructor for tests — pass an in-memory executor
  /// (e.g. `NativeDatabase.memory()`) instead of touching disk.
  AppDatabase.withExecutor(super.executor);

  /// App-wide singleton, matching ExtensionManager.instance elsewhere in
  /// this codebase — one open database connection for the app's lifetime.
  static final AppDatabase instance = AppDatabase._();

  // Version history:
  //   1 -> initial schema
  //   2 -> added Todos.endDate (nullable), for multi-day tasks — a task
  //        with endDate == null is unchanged, single-day as before.
  //   3 -> added the Contacts table. Contacts used to be rows in
  //        ExtensionRecords (extensionType 'contacts', JSON payload);
  //        the upgrade moves them into the new table.
  //   4 -> added Todos.completedAt / archivedAt / deletedAt (nullable),
  //        for the Archive and the Trash. These must NOT live in the
  //        version-3 step: a phone that already upgraded to 3 (for
  //        Contacts) never runs that step again, so it would never get
  //        the columns.
  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(todos, todos.endDate);
      }
      if (from < 3) {
        await m.createTable(contacts);
        // Explicit `this.`: extension methods are reliably found through
        // an explicit receiver, which is the safe form to rely on here.
        // ignore: unnecessary_this
        await this.migrateLegacyContacts();
      }
      if (from < 4) {
        // "If missing" because a database that was created fresh while
        // the columns were still part of the version-3 step already has
        // them, and adding a column twice is a hard SQL error.
        await _addColumnIfMissing(m, todos, todos.completedAt);
        await _addColumnIfMissing(m, todos, todos.archivedAt);
        await _addColumnIfMissing(m, todos, todos.deletedAt);
      }
    },
  );

  /// Adds [column] to [table] unless the table already has a column of
  /// that name.
  Future<void> _addColumnIfMissing(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn column,
  ) async {
    final info = await customSelect(
      "PRAGMA table_info('${table.actualTableName}')",
    ).get();
    final exists = info.any((row) => row.read<String>('name') == column.name);
    if (!exists) await m.addColumn(table, column);
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'taskflow');
  }
}
