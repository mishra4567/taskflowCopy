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

export 'tables/todos_table.dart';
export 'tables/subtasks_table.dart';
export 'tables/extensions_table.dart';
export 'tables/extension_records_table.dart';
export 'daos/todo_queries.dart';
export 'daos/extension_queries.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Todos, Subtasks, Extensions, ExtensionRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  /// Constructor for tests — pass an in-memory executor
  /// (e.g. `NativeDatabase.memory()`) instead of touching disk.
  AppDatabase.withExecutor(super.executor);

  /// App-wide singleton, matching ExtensionManager.instance elsewhere in
  /// this codebase — one open database connection for the app's lifetime.
  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'taskflow');
  }
}
