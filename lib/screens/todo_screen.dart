// screens/todo_screen
import 'package:flutter/material.dart';
import '../models/todo_task.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/todo_task_sheet.dart';

/// TODO List tab — filterable, grouped agenda of tasks with an inline
/// add/edit sheet. Data is hardcoded via TodoTask.sampleTasks() until a
/// storage layer (sqflite/Hive — undecided) is wired up.
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  late List<TodoTask> _tasks;
  TaskPriority? _priorityFilter; // null = All

  @override
  void initState() {
    super.initState();
    _tasks = TodoTask.sampleTasks();
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
      },
      onDelete: existing == null
          ? null
          : () =>
                setState(() => _tasks.removeWhere((t) => t.id == existing.id)),
    );
  }

  void _toggleDone(TodoTask task) {
    setState(() => task.isDone = !task.isDone);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final visible = _priorityFilter == null
        ? _tasks
        : _tasks.where((t) => t.priority == _priorityFilter).toList();

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
                  'No tasks match this filter',
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
