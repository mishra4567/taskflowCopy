/// data/tables/subtasks_tables.dart
import 'package:drift/drift.dart';

import 'todos_table.dart';

/// Subtasks belong to a Todo — a real relational example (one-to-many),
/// the kind of thing that's awkward in a key-value store like Hive but
/// natural here: `select(subtasks)..where((s) => s.todoId.equals(id))`.
class Subtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get todoId => text().references(Todos, #id)();
  TextColumn get title => text()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
}
