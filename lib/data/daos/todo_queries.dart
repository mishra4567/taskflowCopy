/// data/daos/todo_queries.dart
import '../app_database.dart';

/// Todo/Subtask query methods, kept in their own file rather than piled
/// into AppDatabase directly — new query logic for a given concern lives
/// next to that concern, and this file stays focused on just Todos.
extension TodoQueries on AppDatabase {
  Future<List<TodoWithSubtasks>> getAllTodosWithSubtasks() async {
    final todoRows = await select(todos).get();
    final result = <TodoWithSubtasks>[];
    for (final todo in todoRows) {
      final subtaskRows = await (select(
        subtasks,
      )..where((s) => s.todoId.equals(todo.id))).get();
      result.add(TodoWithSubtasks(todo: todo, subtasks: subtaskRows));
    }
    return result;
  }

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

  Future<void> deleteTodo(String todoId) async {
    await (delete(subtasks)..where((s) => s.todoId.equals(todoId))).go();
    await (delete(todos)..where((t) => t.id.equals(todoId))).go();
  }
}

/// Plain bundle of a todo row plus its subtask rows — not a Drift type
/// itself, just a convenience wrapper so callers don't juggle two lists.
class TodoWithSubtasks {
  TodoWithSubtasks({required this.todo, required this.subtasks});
  final Todo todo;
  final List<Subtask> subtasks;
}
