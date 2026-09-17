/// data/tables/todos_table.dart
import 'package:drift/drift.dart';

/// A single TODO task. Mirrors TodoTask in lib/models/todo_task.dart —
/// `priority` is stored as text ('low' | 'medium' | 'high') rather than an
/// int enum index, so the raw row is human-readable if you ever inspect
/// the .sqlite file directly.
class Todos extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get category => text()();
  TextColumn get priority => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  BoolColumn get notificationEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get alarmEnabled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
