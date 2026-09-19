// todo_screen
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import '../data/app_database.dart';
import '../models/todo_task.dart';
import '../services/todo_refresh_bus.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/todo_task_sheet.dart';

/// TODO List tab — filterable, grouped agenda of tasks with an inline
/// add/edit sheet. Backed by AppDatabase (Drift/SQLite): the in-memory
/// `_tasks` list is the UI's working copy for snappy interaction, and
/// every mutation writes through to the database immediately.
///
/// Rendered inside MainShell rather than pushed over it, so the bottom
/// nav and FAB stay visible; the AppBar here is this screen's own (the
/// shell hides its bar for this page).
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key, required this.onBack, this.initialDateFilter});

  /// Because this page lives inside the shell, there's no route to pop —
  /// "back" asks the shell to switch to the previously active tab.
  final VoidCallback onBack;

  /// Set when arriving here from Calendar's "View in TODO" — filters the
  /// list to tasks due on this date. Null for the normal Home → TODO path.
  final DateTime? initialDateFilter;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<TodoTask> _tasks = [];
  bool _loading = true;
  TaskPriority? _priorityFilter; // null = All
  DateTime? _dateFilter;

  bool _isSameDate(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _dateFilter = widget.initialDateFilter;
    _loadTasks();
    // A task added elsewhere (the quick-add FAB) writes straight to the
    // database and can't reach this screen's in-memory _tasks list any
    // other way, so listen for that signal and reload when it fires.
    TodoRefreshBus.tick.addListener(_loadTasks);
  }

  @override
  void dispose() {
    TodoRefreshBus.tick.removeListener(_loadTasks);
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final bundles = await AppDatabase.instance.getAllTodosWithSubtasks();
    final loaded = bundles.map(TodoTask.fromBundle).toList();
    if (!mounted) return;
    setState(() {
      _tasks = loaded;
      _loading = false;
    });
  }

  Future<void> _persistTask(TodoTask task) async {
    await AppDatabase.instance.upsertTodo(
      TodosCompanion.insert(
        id: task.id,
        title: task.title,
        category: task.category,
        priority: task.priority.name,
        dueDate: Value(task.dueDate),
        isDone: Value(task.isDone),
        notificationEnabled: Value(task.notificationEnabled),
        alarmEnabled: Value(task.alarmEnabled),
      ),
    );
    await AppDatabase.instance.replaceSubtasksForTodo(
      task.id,
      task.subtasks
          .map(
            (s) => SubtasksCompanion.insert(
              todoId: task.id,
              title: s.title,
              isDone: Value(s.isDone),
            ),
          )
          .toList(),
    );
  }

  void _openSheet({TodoTask? existing}) {
    showTodoTaskSheet(
      context,
      existing: existing,
      onSave: (task) {
        setState(() {
          final i = _tasks.indexWhere((t) => t.id == task.id);
          if (i == -1) {
            _tasks.add(task);
          } else {
            _tasks[i] = task;
          }
        });
        _persistTask(task);
      },
      onDelete: existing == null
          ? null
          : () {
              setState(() => _tasks.removeWhere((t) => t.id == existing.id));
              AppDatabase.instance.deleteTodo(existing.id);
            },
    );
  }

  void _toggleDone(TodoTask task) {
    setState(() => task.isDone = !task.isDone);
    _persistTask(task);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final visible = _tasks.where((t) {
      final matchesPriority =
          _priorityFilter == null || t.priority == _priorityFilter;
      final matchesDate =
          _dateFilter == null || _isSameDate(t.dueDate, _dateFilter!);
      return matchesPriority && matchesDate;
    }).toList();

    final pending = visible.where((t) => !t.isDone).toList();
    final completed = visible.where((t) => t.isDone).toList();

    List<TodoTask> bucket(
      bool Function(DateTime) test, {
      bool includeNull = false,
    }) {
      return pending.where((t) {
        if (t.dueDate == null) return includeNull;
        final d = DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
        return test(d);
      }).toList()..sort((a, b) => a.priority.index.compareTo(b.priority.index));
    }

    final overdue = bucket((d) => d.isBefore(todayDate));
    final dueToday = bucket((d) => d.isAtSameMomentAs(todayDate));
    final upcoming = bucket((d) => d.isAfter(todayDate));
    final noDate = bucket((_) => false, includeNull: true);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('My Tasks'),
        actions: [
          IconButton(
            onPressed: () => _openSheet(),
            icon: Icon(
              Icons.add_circle_outline,
              color: colors.primaryContainer,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.containerMargin,
          AppSpacing.md,
          AppSpacing.containerMargin,
          140,
        ),
        children: [
          if (_dateFilter != null) ...[
            _DateFilterBanner(
              date: _dateFilter!,
              onClear: () => setState(() => _dateFilter = null),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _priorityFilter == null,
                  onTap: () => setState(() => _priorityFilter = null),
                ),
                const SizedBox(width: 8),
                for (final p in TaskPriority.values) ...[
                  _FilterChip(
                    label: p.label,
                    color: p.color(colors),
                    selected: _priorityFilter == p,
                    onTap: () => setState(() => _priorityFilter = p),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (pending.isEmpty && completed.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  _tasks.isEmpty
                      ? 'No tasks yet — tap + to add one.'
                      : 'No tasks match this filter',
                  style: AppTypography.bodySm.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),

          if (overdue.isNotEmpty)
            _Section(
              label: 'OVERDUE',
              tasks: overdue,
              onTap: _openSheet,
              onToggle: _toggleDone,
            ),
          if (dueToday.isNotEmpty)
            _Section(
              label: 'TODAY',
              tasks: dueToday,
              onTap: _openSheet,
              onToggle: _toggleDone,
            ),
          if (upcoming.isNotEmpty)
            _Section(
              label: 'UPCOMING',
              tasks: upcoming,
              onTap: _openSheet,
              onToggle: _toggleDone,
            ),
          if (noDate.isNotEmpty)
            _Section(
              label: 'NO DUE DATE',
              tasks: noDate,
              onTap: _openSheet,
              onToggle: _toggleDone,
            ),
          if (completed.isNotEmpty)
            _Section(
              label: 'COMPLETED',
              tasks: completed,
              onTap: _openSheet,
              onToggle: _toggleDone,
            ),
        ],
      ),
    );
  }
}

class _DateFilterBanner extends StatelessWidget {
  const _DateFilterBanner({required this.date, required this.onClear});

  final DateTime date;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.standard),
        border: Border.all(color: colors.primaryContainer),
      ),
      child: Row(
        children: [
          Icon(Icons.event, size: 16, color: colors.primaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing tasks due ${date.day}/${date.month}/${date.year}',
              style: AppTypography.bodySm.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 16, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = color ?? colors.primaryContainer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.2)
              : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : colors.borderSubtle),
        ),
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(
            color: selected ? accent : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.tasks,
    required this.onTap,
    required this.onToggle,
  });

  final String label;
  final List<TodoTask> tasks;
  final void Function({TodoTask? existing}) onTap;
  final ValueChanged<TodoTask> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.labelCaps.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final task in tasks) ...[
            _TaskCard(
              task: task,
              onTap: () => onTap(existing: task),
              onToggle: () => onToggle(task),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onTap,
    required this.onToggle,
  });

  final TodoTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  String _dueLabel(DateTime today) {
    final d = task.dueDate!;
    final dueDate = DateTime(d.year, d.month, d.day);
    final diff = dueDate.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 0) return 'Overdue · ${d.day}/${d.month}';
    return '${d.day}/${d.month}/${d.year}';
  }

  /// Time isn't its own field on TodoTask — it rides along inside
  /// dueDate — so a plain date-only due date (saved as midnight) has
  /// nothing to show here, and this returns null for it.
  String? _timeLabel(BuildContext context) {
    final d = task.dueDate!;
    if (d.hour == 0 && d.minute == 0) return null;
    return TimeOfDay.fromDateTime(d).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final isOverdue =
        task.dueDate != null &&
        DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        ).isBefore(todayDate) &&
        !task.isDone;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.standard),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Icon(
                  task.isDone
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: task.isDone ? colors.tertiary : colors.outline,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: AppTypography.bodyMd.copyWith(
                        color: task.isDone
                            ? colors.textSecondary
                            : colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: task.priority.color(colors),
                          ),
                        ),
                        Text(
                          task.category,
                          style: AppTypography.bodySm.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        if (task.dueDate != null) ...[
                          Text(
                            '·',
                            style: AppTypography.bodySm.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            _dueLabel(todayDate),
                            style: AppTypography.bodySm.copyWith(
                              color: isOverdue
                                  ? colors.error
                                  : colors.textSecondary,
                              fontWeight: isOverdue
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          if (_timeLabel(context) != null)
                            Text(
                              _timeLabel(context)!,
                              style: AppTypography.bodySm.copyWith(
                                color: isOverdue
                                    ? colors.error
                                    : colors.textSecondary,
                              ),
                            ),
                        ],
                        if (task.hasSubtasks) ...[
                          Text(
                            '·',
                            style: AppTypography.bodySm.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          Text(
                            '${task.subtaskDoneCount}/${task.subtasks.length}',
                            style: AppTypography.bodySm.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        if (task.notificationEnabled)
                          Icon(
                            Icons.notifications_none,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                        if (task.alarmEnabled)
                          Icon(
                            Icons.alarm,
                            size: 14,
                            color: colors.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
