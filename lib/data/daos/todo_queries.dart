/// data/daos/todo_queries.dart
// The `&` between two conditions is an extension operator that lives in
// drift itself, not on AppDatabase — without this import it's reported
// as "operator '&' isn't defined for the type 'Expression<bool>'".
import 'package:drift/drift.dart';

import '../app_database.dart';

/// Todo/Subtask query methods, kept in their own file rather than piled
/// into AppDatabase directly.
extension TodoQueries on AppDatabase {
  /// Main-list tasks only — archived and trashed ones are excluded, so
  /// TodoScreen, Calendar, Home counts and rescheduleAllAlarms all ignore
  /// them without each needing its own filter. Use
  /// [getEveryTodoWithSubtasks] when you genuinely need every row (backup).
  Future<List<TodoWithSubtasks>> getAllTodosWithSubtasks() async {
    final rows = await (select(
      todos,
    )..where((t) => t.archivedAt.isNull() & t.deletedAt.isNull())).get();
    return _withSubtasks(rows);
  }

  /// Every row, including archived and trashed ones.
  Future<List<TodoWithSubtasks>> getEveryTodoWithSubtasks() async {
    return _withSubtasks(await select(todos).get());
  }

  Future<List<TodoWithSubtasks>> _withSubtasks(List<Todo> rows) async {
    final result = <TodoWithSubtasks>[];
    for (final todo in rows) {
      final subtaskRows = await (select(
        subtasks,
      )..where((s) => s.todoId.equals(todo.id))).get();
      result.add(TodoWithSubtasks(todo: todo, subtasks: subtaskRows));
    }
    return result;
  }

  /// Insert-or-update. On update, only the columns present on [todo] are
  /// written, so editing a task never clears archivedAt/deletedAt.
  Future<void> upsertTodo(TodosCompanion todo) {
    return into(todos).insertOnConflictUpdate(todo);
  }

  Future<void> replaceSubtasksForTodo(
    String todoId,
    List<SubtasksCompanion> newSubtasks,
  ) async {
    await (delete(subtasks)..where((s) => s.todoId.equals(todoId))).go();
    for (final s in newSubtasks) {
      await into(subtasks).insert(s);
    }
  }

  /// Permanent delete. App code should go through TaskBinService.
  Future<void> deleteTodo(String todoId) async {
    await (delete(subtasks)..where((s) => s.todoId.equals(todoId))).go();
    await (delete(todos)..where((t) => t.id.equals(todoId))).go();
  }
}

/// Plain bundle of a todo row plus its subtask rows.
class TodoWithSubtasks {
  TodoWithSubtasks({required this.todo, required this.subtasks});
  final Todo todo;
  final List<Subtask> subtasks;
}
