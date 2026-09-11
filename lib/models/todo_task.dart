// models/todo_task
import 'package:flutter/material.dart';
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
    this.isDone = false,
    this.notificationEnabled = false,
    this.alarmEnabled = false,
    List<Subtask>? subtasks,
  }) : subtasks = subtasks ?? [];

  final String id;
  String title;
  String category;
  TaskPriority priority;
  DateTime? dueDate;
  bool isDone;
  bool notificationEnabled;
  bool alarmEnabled;
  final List<Subtask> subtasks;

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
      isDone: isDone ?? this.isDone,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      subtasks: subtasks ?? this.subtasks,
    );
  }

  /// Fixed sample data — swap for a real query once storage is wired up.
  static List<TodoTask> sampleTasks() {
    final today = DateTime.now();
    DateTime daysFromNow(int n) =>
        DateTime(today.year, today.month, today.day + n);

    return [
      TodoTask(
        id: 't1',
        title: 'Finalize Q3 Strategy Deck',
        category: 'Work',
        priority: TaskPriority.high,
        dueDate: daysFromNow(0),
        notificationEnabled: true,
      ),
      TodoTask(
        id: 't2',
        title: 'Review Design System tokens',
        category: 'Design',
        priority: TaskPriority.medium,
        dueDate: daysFromNow(-2),
        isDone: true,
      ),
      TodoTask(
        id: 't3',
        title: 'Pay electricity bill',
        category: 'Personal',
        priority: TaskPriority.low,
        dueDate: daysFromNow(3),
        alarmEnabled: true,
      ),
      TodoTask(
        id: 't4',
        title: 'Plan roadmap sync with team',
        category: 'Work',
        priority: TaskPriority.medium,
        subtasks: [
          Subtask(title: 'Draft agenda', isDone: true),
          Subtask(title: 'Send calendar invite'),
        ],
      ),
    ];
  }
}
