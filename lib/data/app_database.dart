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
import 'tables/expenses_table.dart'; // SPEND
// Imported (not just exported below) because the migration calls
// migrateLegacyContacts(), an extension method defined in this file.
import 'daos/contact_queries.dart';
import 'tables/sync_tombstones_table.dart'; // SYNC

export 'tables/todos_table.dart';
export 'tables/subtasks_table.dart';
export 'tables/extensions_table.dart';
export 'tables/extension_records_table.dart';
export 'tables/contacts_table.dart';
export 'tables/expenses_table.dart'; // SPEND
export 'daos/todo_queries.dart';
export 'daos/extension_queries.dart';
export 'daos/contact_queries.dart';
export 'daos/expense_queries.dart'; // SPEND
export 'tables/sync_tombstones_table.dart'; // SYNC

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Todos,
    Subtasks,
    Extensions,
    ExtensionRecords,
    Contacts,
    Expenses, // SPEND
    SyncTombstones, // SYNC
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  // Constructor for tests — pass an in-memory executor
  // (e.g. `NativeDatabase.memory()`) instead of touching disk.
  AppDatabase.withExecutor(super.executor);

  // App-wide singleton, matching ExtensionManager.instance elsewhere in
  // this codebase — one open database connection for the app's lifetime.
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
  //   5 -> added the Expenses table (payments / spending).
  @override
  // int get schemaVersion => 7; // SPEND
  // int get schemaVersion => 8; // SYNC
  int get schemaVersion => 9;
  // Version history:
  //   1 -> initial schema
  //   2 -> added Todos.endDate (nullable), for multi-day tasks
  //   3 -> added the Contacts table (moved out of ExtensionRecords)
  //   4 -> added Todos.completedAt / archivedAt / deletedAt
  //   5 -> added the Expenses table
  //   6 -> added Expenses.source
  //   7 -> added Expenses.direction
  //   8 -> added sync support: sync_tombstones table, Todos.updatedAt,
  //        Expenses.uuid / updatedAt, plus the triggers in
  //        _ensureSyncSchema that keep updatedAt current and record
  //        tombstones automatically

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _ensureSyncSchema(); // SYNC
    },
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
      if (from < 5) {
        // SPEND
        await m.createTable(expenses);
      }
      if (from < 6) {
        // SPEND
        await _addColumnIfMissing(m, expenses, expenses.source);
      }
      if (from < 7) {
        // SPEND
        await _addColumnIfMissing(m, expenses, expenses.direction);
      }
      if (from < 8) {
        // SYNC
        await m.createTable(syncTombstones);
        await _addColumnIfMissing(m, todos, todos.updatedAt);
        await _addColumnIfMissing(m, expenses, expenses.uuid);
        await _addColumnIfMissing(m, expenses, expenses.updatedAt);
        // Existing rows count as "changed now", so the first sync uploads
        // everything, and every expense gets an id.
        const now = "CAST(strftime('%s','now') AS INTEGER)";
        await customStatement(
          'UPDATE todos SET updated_at = $now WHERE updated_at = 0',
        );
        await customStatement(
          'UPDATE expenses SET updated_at = $now WHERE updated_at = 0',
        );
        await customStatement(
          'UPDATE expenses SET uuid = lower(hex(randomblob(16))) '
          'WHERE uuid IS NULL',
        );
      }
      if (from < 9) {
        await _addColumnIfMissing(m, contacts, contacts.uuid);
        await _addColumnIfMissing(m, contacts, contacts.updatedAt);

        // Give existing contacts a permanent sync identity.
        await customStatement(
          "UPDATE contacts "
          "SET uuid = lower(hex(randomblob(16))) "
          "WHERE uuid IS NULL OR uuid = ''",
        );

        await customStatement(
          "UPDATE contacts "
          "SET updated_at = CAST(strftime('%s','now') AS INTEGER) "
          "WHERE updated_at = 0",
        );
      }
    },
    // The triggers are IF NOT EXISTS, so (re)creating them on every open is
    // cheap and means no migration path can leave them missing.
    beforeOpen: (details) async => _ensureSyncSchema(), // SYNC
  );

  // Adds [column] to [table] unless the table already has a column of
  // that name.
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

  /// The sync triggers. They keep updated_at current without any save path
  /// having to remember to, assign expense uuids, and record permanent
  /// deletes. The WHEN clauses are what stop a pulled row from being
  /// treated as a local edit: a sync write sets updated_at itself, so the
  /// triggers leave it alone and it isn't uploaded straight back.
  Future<void> _ensureSyncSchema() async {
    const now = "CAST(strftime('%s','now') AS INTEGER)";
    final statements = <String>[
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_uuid ON expenses(uuid)',

      // ---- tasks (todos.id is the id on every phone)
      '''CREATE TRIGGER IF NOT EXISTS trg_todos_ai AFTER INSERT ON todos
         WHEN NEW.updated_at = 0
         BEGIN UPDATE todos SET updated_at = $now WHERE id = NEW.id; END''',
      '''CREATE TRIGGER IF NOT EXISTS trg_todos_ai_tomb AFTER INSERT ON todos
         BEGIN DELETE FROM sync_tombstones
           WHERE kind = 'task' AND uuid = NEW.id; END''',
      '''CREATE TRIGGER IF NOT EXISTS trg_todos_au AFTER UPDATE ON todos
         WHEN NEW.updated_at = OLD.updated_at
         BEGIN UPDATE todos SET updated_at = $now WHERE id = NEW.id; END''',
      '''CREATE TRIGGER IF NOT EXISTS trg_todos_ad AFTER DELETE ON todos
         BEGIN INSERT OR REPLACE INTO sync_tombstones (kind, uuid, deleted_at)
           VALUES ('task', OLD.id, $now); END''',

      // ---- expenses
      '''CREATE TRIGGER IF NOT EXISTS trg_expenses_ai AFTER INSERT ON expenses
         WHEN NEW.uuid IS NULL OR NEW.updated_at = 0
         BEGIN UPDATE expenses SET
           uuid = COALESCE(uuid, lower(hex(randomblob(16)))),
           updated_at = CASE WHEN updated_at = 0 THEN $now ELSE updated_at END
         WHERE id = NEW.id; END''',
      '''CREATE TRIGGER IF NOT EXISTS trg_expenses_ai_tomb
         AFTER INSERT ON expenses WHEN NEW.uuid IS NOT NULL
         BEGIN DELETE FROM sync_tombstones
           WHERE kind = 'expense' AND uuid = NEW.uuid; END''',
      '''CREATE TRIGGER IF NOT EXISTS trg_expenses_au AFTER UPDATE ON expenses
         WHEN NEW.updated_at = OLD.updated_at
         BEGIN UPDATE expenses SET updated_at = $now WHERE id = NEW.id; END''',
      '''CREATE TRIGGER IF NOT EXISTS trg_expenses_ad AFTER DELETE ON expenses
         WHEN OLD.uuid IS NOT NULL
         BEGIN INSERT OR REPLACE INTO sync_tombstones (kind, uuid, deleted_at)
           VALUES ('expense', OLD.uuid, $now); END''',
      // ---- contacts

      '''CREATE UNIQUE INDEX IF NOT EXISTS idx_contacts_uuid
   ON contacts(uuid)''',

      '''CREATE TRIGGER IF NOT EXISTS trg_contacts_ai
   AFTER INSERT ON contacts
   WHEN NEW.updated_at = 0
   BEGIN
     UPDATE contacts
     SET updated_at = $now
     WHERE id = NEW.id;
   END''',

      '''CREATE TRIGGER IF NOT EXISTS trg_contacts_ai_tomb
   AFTER INSERT ON contacts
   WHEN NEW.uuid IS NOT NULL
   BEGIN
     DELETE FROM sync_tombstones
     WHERE kind = 'contact' AND uuid = NEW.uuid;
   END''',

      '''CREATE TRIGGER IF NOT EXISTS trg_contacts_au
   AFTER UPDATE ON contacts
   WHEN NEW.updated_at = OLD.updated_at
   BEGIN
     UPDATE contacts
     SET updated_at = $now
     WHERE id = NEW.id;
   END''',

      '''CREATE TRIGGER IF NOT EXISTS trg_contacts_ad
   AFTER DELETE ON contacts
   WHEN OLD.uuid IS NOT NULL
   BEGIN
     INSERT OR REPLACE INTO sync_tombstones
       (kind, uuid, deleted_at)
     VALUES ('contact', OLD.uuid, $now);
   END''',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'taskflow');
  }
}
