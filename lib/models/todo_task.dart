// models/todo_task
import 'package:flutter/material.dart';
import 'package:taskflow/data/app_database.dart';
import '../theme/app_palette.dart';

/// Priority levels a task can be tagged with. Plain enum with a
/// switch-based label/color lookup — no recursive getters, nothing that
/// calls back into TodoTask, so there's no risk of the kind of infinite
/// loop that a self-referential model can cause.
enum TaskPriority {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  Color color(AppPalette colors) {
    switch (this) {
      case TaskPriority.low:
        return colors.tertiary;
      case TaskPriority.medium:
        return colors.primary;
      case TaskPriority.high:
        return colors.error;
    }
  }
}

/// A single subtask/checklist item under a task.
class Subtask {
  Subtask({required this.title, this.isDone = false});

  final String title;
  bool isDone;
}

/// A single TODO item. Mutable on purpose (TodoScreen flips `isDone` in
/// place) since there's no reactive database wired up yet — this is plain
/// in-memory state for sample data, not a persistence model.
class TodoTask {
  TodoTask({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    this.dueDate,
    this.endDate,
    this.isDone = false,
    this.notificationEnabled = false,
    this.alarmEnabled = false,
    List<Subtask>? subtasks,
  }) : subtasks = subtasks ?? [];

  final String id;
  String title;
  String category;
  TaskPriority priority;

  /// Doubles as the task's start date/time once [endDate] is set (a
  /// multi-day task) — null [endDate] means an ordinary single-day task,
  /// exactly as before multi-day existed.
  DateTime? dueDate;

  /// Non-null only for a multi-day task; the day/time it ends on.
  DateTime? endDate;

  bool isDone;
  bool notificationEnabled;
  bool alarmEnabled;
  final List<Subtask> subtasks;

  /// True when this task spans more than one calendar day — i.e. has
  /// both a start ([dueDate]) and an [endDate] on a later date. A task
  /// with the same start and end date counts as single-day, same as one
  /// with no endDate at all.
  bool get isMultiDay {
    if (dueDate == null || endDate == null) return false;
    final start = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return end.isAfter(start);
  }

  /// Maps a database row (todo + its subtasks) to a TodoTask — the one
  /// place this mapping happens, so TodoScreen and CalendarScreen (and
  /// anything else that reads todos) share the same logic instead of
  /// each re-deriving it.
  factory TodoTask.fromBundle(TodoWithSubtasks bundle) {
    final row = bundle.todo;
    return TodoTask(
      id: row.id,
      title: row.title,
      category: row.category,
      priority: TaskPriority.values.byName(row.priority),
      dueDate: row.dueDate,
      endDate: row.endDate,
      isDone: row.isDone,
      notificationEnabled: row.notificationEnabled,
      alarmEnabled: row.alarmEnabled,
      subtasks: bundle.subtasks
          .map((s) => Subtask(title: s.title, isDone: s.isDone))
          .toList(),
    );
  }

  bool get hasSubtasks => subtasks.isNotEmpty;
  int get subtaskDoneCount => subtasks.where((s) => s.isDone).length;

  /// Returns a new TodoTask with the given fields replaced, rather than
  /// mutating in place — so a cancelled edit in the sheet never leaves
  /// partial changes on the original object.
  TodoTask copyWith({
    String? title,
    String? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? isDone,
    bool? notificationEnabled,
    bool? alarmEnabled,
    List<Subtask>? subtasks,
  }) {
    return TodoTask(
      id: id,
      title: title ?? this.title,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      isDone: isDone ?? this.isDone,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      subtasks: subtasks ?? this.subtasks,
    );
  }
}
