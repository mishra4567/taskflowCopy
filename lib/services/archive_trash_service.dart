// services/archive_trash_service.dart
import 'package:drift/drift.dart';
import 'package:taskflow/data/app_database.dart';
import 'package:taskflow/models/todo_task.dart';
import 'package:taskflow/services/notification_service.dart';
import 'package:taskflow/services/todo_refresh_bus.dart';

/// A task sitting in the Archive or the Trash, plus when it got there.
class BinEntry {
  const BinEntry({required this.task, this.archivedAt, this.deletedAt});

  final TodoTask task;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
}

/// Everything about hiding tasks without destroying them.
///
/// A task is in exactly one of three places, decided by two timestamps
/// on its row:
///
/// * **Main list** — archivedAt and deletedAt are both null.
/// * **Archive** — archivedAt is set, deletedAt is null.
/// * **Trash** — deletedAt is set. archivedAt is left as it was, so a
///   task that was archived and then deleted goes back to the *Archive*
///   when restored, not the main list: restoring undoes the delete and
///   nothing else.
///
/// Archived and trashed tasks never have a live reminder — it's cancelled
/// when they leave the main list and re-armed when they return.
///
/// Every change here calls [TodoRefreshBus.notify], so the TODO list and
/// Calendar reload on their own.
class TaskBinService {
  TaskBinService._();
  static final TaskBinService instance = TaskBinService._();

  /// How long a task stays completed before it's archived automatically.
  static const autoArchiveAfter = Duration(days: 7);

  AppDatabase get _db => AppDatabase.instance;

  // --------------------------------------------------------------- reading

  /// Archived tasks (not in the Trash), most recently archived first.
  Future<List<BinEntry>> archived() async {
    final entries = await _select(trashed: false);
    entries.sort((a, b) => b.archivedAt!.compareTo(a.archivedAt!));
    return entries;
  }

  /// Trashed tasks, most recently deleted first.
  Future<List<BinEntry>> trashed() async {
    final entries = await _select(trashed: true);
    entries.sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return entries;
  }

  Future<int> archivedCount() async => (await archived()).length;
  Future<int> trashedCount() async => (await trashed()).length;

  // ------------------------------------------------------------ completion

  /// Stamps (or clears) when a task was completed. Call from the checkbox
  /// toggle, so the 7-day auto-archive clock starts when you tick it.
  Future<void> recordCompletion(String id, {required bool done}) => _write(
    id,
    TodosCompanion(completedAt: Value(done ? DateTime.now() : null)),
  );

  // --------------------------------------------------------------- archive

  Future<void> archive(String id) async {
    await _write(id, TodosCompanion(archivedAt: Value(DateTime.now())));
    await _cancelReminders(id);
    TodoRefreshBus.notify();
  }

  Future<void> unarchive(String id) async {
    final entry = await _find(id);
    await _write(
      id,
      TodosCompanion(
        archivedAt: const Value<DateTime?>(null),
        // A completed task coming back would otherwise be archived again
        // by the very next sweep (it finished more than 7 days ago), so
        // it gets a fresh 7 days.
        completedAt: entry != null && entry.task.isDone
            ? Value(DateTime.now())
            : const Value.absent(),
      ),
    );
    await _resyncReminders(id);
    TodoRefreshBus.notify();
  }

  // ----------------------------------------------------------------- trash

  Future<void> moveToTrash(String id) async {
    await _write(id, TodosCompanion(deletedAt: Value(DateTime.now())));
    await _cancelReminders(id);
    TodoRefreshBus.notify();
  }

  Future<void> restoreFromTrash(String id) async {
    final entry = await _find(id);
    // Only a task landing back in the *main list* (not the Archive) needs
    // a fresh 7 days. One expression, so `entry` is known non-null.
    final needsFreshWeek =
        entry != null && entry.archivedAt == null && entry.task.isDone;
    await _write(
      id,
      TodosCompanion(
        deletedAt: const Value<DateTime?>(null),
        completedAt: needsFreshWeek
            ? Value(DateTime.now())
            : const Value.absent(),
      ),
    );
    await _resyncReminders(id);
    TodoRefreshBus.notify();
  }

  /// Permanently removes one task (and its subtasks). Not undoable.
  Future<void> deleteForever(String id) async {
    await _db.deleteTodo(id);
    await _cancelReminders(id);
    TodoRefreshBus.notify();
  }

  /// Permanently removes everything in the Trash. Returns how many tasks
  /// that was. Not undoable.
  Future<int> emptyTrash() async {
    final ids = [for (final e in await trashed()) e.task.id];
    await _db.transaction(() async {
      for (final id in ids) {
        await _db.deleteTodo(id);
      }
    });
    for (final id in ids) {
      await _cancelReminders(id);
    }
    if (ids.isNotEmpty) TodoRefreshBus.notify();
    return ids.length;
  }

  // ---------------------------------------------------------- auto-archive

  /// Archives every completed task that finished more than
  /// [autoArchiveAfter] ago. Returns how many it archived. Cheap enough
  /// to run on every app start.
  ///
  /// A completed task with no completedAt (finished before that column
  /// existed) has its 7 days start *now* rather than being archived on
  /// the spot — otherwise installing this would instantly sweep away
  /// every old completed task.
  Future<int> autoArchiveCompleted() async {
    final now = DateTime.now();
    final cutoff = now.subtract(autoArchiveAfter);

    await (_db.update(_db.todos)..where(
          (t) =>
              t.isDone.equals(true) &
              t.completedAt.isNull() &
              t.archivedAt.isNull() &
              t.deletedAt.isNull(),
        ))
        .write(TodosCompanion(completedAt: Value(now)));

    final archivedCount =
        await (_db.update(_db.todos)..where(
              (t) =>
                  t.isDone.equals(true) &
                  t.archivedAt.isNull() &
                  t.deletedAt.isNull() &
                  t.completedAt.isSmallerOrEqualValue(cutoff),
            ))
            .write(TodosCompanion(archivedAt: Value(now)));

    if (archivedCount > 0) TodoRefreshBus.notify();
    return archivedCount;
  }

  // --------------------------------------------------------------- helpers

  Future<void> _write(String id, TodosCompanion fields) async {
    await (_db.update(_db.todos)..where((t) => t.id.equals(id))).write(fields);
  }

  Future<BinEntry?> _find(String id) async {
    final found = await _select(id: id);
    return found.isEmpty ? null : found.first;
  }

  /// One query for every lookup in this file. [trashed] true = in the
  /// Trash, false = archived and not trashed, null = no such filter;
  /// [id] narrows to one task.
  Future<List<BinEntry>> _select({bool? trashed, String? id}) async {
    final rows =
        await (_db.select(_db.todos)..where((t) {
              Expression<bool> condition = const Constant(true);
              if (id != null) condition = condition & t.id.equals(id);
              if (trashed == true) {
                condition = condition & t.deletedAt.isNotNull();
              } else if (trashed == false) {
                condition =
                    condition & t.archivedAt.isNotNull() & t.deletedAt.isNull();
              }
              return condition;
            }))
            .get();

    return [
      for (final r in rows)
        BinEntry(
          task: TodoTask(
            id: r.id,
            title: r.title,
            category: r.category,
            priority: TaskPriority.values.firstWhere(
              (p) => p.name == r.priority,
              orElse: () => TaskPriority.medium,
            ),
            dueDate: r.dueDate,
            endDate: r.endDate,
            isDone: r.isDone,
            notificationEnabled: r.notificationEnabled,
            alarmEnabled: r.alarmEnabled,
          ),
          archivedAt: r.archivedAt,
          deletedAt: r.deletedAt,
        ),
    ];
  }

  Future<void> _cancelReminders(String id) async {
    // A reminder problem (e.g. notifications switched off) must never
    // turn a successful archive/delete into a reported failure.
    try {
      final notifications = NotificationService.instance;
      await notifications.cancelTaskNotification(id);
      await notifications.cancelTaskAlarm(id);
    } catch (_) {}
  }

  /// Re-arms a task's reminders after it returns to the main list — the
  /// same rule every other save path uses: only for a task that has a due
  /// date, isn't done, and has the switch on.
  Future<void> _resyncReminders(String id) async {
    final entry = await _find(id);
    if (entry == null) return;
    final task = entry.task;
    // Still hidden (e.g. restored from Trash into the Archive): no reminder.
    if (entry.archivedAt != null || entry.deletedAt != null) {
      await _cancelReminders(id);
      return;
    }
    final live = task.dueDate != null && !task.isDone;
    try {
      final notifications = NotificationService.instance;
      if (task.notificationEnabled && live) {
        await notifications.scheduleTaskNotification(task);
      } else {
        await notifications.cancelTaskNotification(id);
      }
      if (task.alarmEnabled && live) {
        await notifications.scheduleTaskAlarm(task);
      } else {
        await notifications.cancelTaskAlarm(id);
      }
    } catch (_) {}
  }
}
