// calender_screen
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../models/todo_task.dart';
import '../services/notification_service.dart';
import '../services/todo_refresh_bus.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../screens/todoscreen/todo_task_sheet.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar tab — monthly grid with due-date markers pulled from real
/// tasks, plus an agenda list for whichever day is selected. Tapping a
/// day both shows its tasks here and offers a "View in TODO" jump that
/// switches to the TODO tab pre-filtered to that date.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.onViewDateInTodo});

  /// Switches MainShell to the TODO tab, filtered to the given date.
  final ValueChanged<DateTime> onViewDateInTodo;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  final DateTime _today = DateTime.now();

  bool _loading = true;
  Map<DateTime, List<TodoTask>> _eventsByDate = {};

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(_today.year, _today.month);
    _selectedDate = DateTime(_today.year, _today.month, _today.day);
    _loadEvents();
    // Adding/editing a task anywhere (TODO tab, quick-add) should move
    // its marker here without needing to leave and re-enter this tab.
    TodoRefreshBus.tick.addListener(_loadEvents);
  }

  @override
  void dispose() {
    TodoRefreshBus.tick.removeListener(_loadEvents);
    super.dispose();
  }

  Future<void> _loadEvents() async {
    final bundles = await AppDatabase.instance.getAllTodosWithSubtasks();
    final tasks = bundles.map(TodoTask.fromBundle).toList();
    final grouped = <DateTime, List<TodoTask>>{};
    for (final task in tasks) {
      final due = task.dueDate;
      if (due == null) continue;
      grouped.putIfAbsent(_dateOnly(due), () => []).add(task);
    }
    if (!mounted) return;
    setState(() {
      _eventsByDate = grouped;
      _loading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(
      () => _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
      ),
    );
  }

  /// Opens the same "New task" sheet TodoScreen uses, pre-filled to the
  /// selected day, and persists it the same way — so the task shows up
  /// in TODO immediately, and here too via TodoRefreshBus (which this
  /// screen already listens to in _loadEvents above).
  void _addTaskForSelectedDate() {
    showTodoTaskSheet(
      context,
      initialDueDate: _selectedDate,
      onSave: (task) async {
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
        if (task.notificationEnabled && task.dueDate != null) {
          await NotificationService.instance.scheduleTaskNotification(task);
        }
        TodoRefreshBus.notify();
      },
    );
  }

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingBlanks = (firstOfMonth.weekday - DateTime.monday) % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    final selectedEvents = _eventsByDate[_dateOnly(_selectedDate)] ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.containerMargin,
        AppSpacing.md,
        AppSpacing.containerMargin,
        140,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
              style: AppTypography.headlineMd.copyWith(
                color: colors.textPrimary,
                fontSize: 20,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: colors.onSurfaceVariant,
                  ),
                  onPressed: () => _changeMonth(-1),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: colors.onSurfaceVariant,
                  ),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final label in _weekdayLabels)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: AppTypography.labelCaps.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var row = 0; row < rowCount; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var col = 0; col < 7; col++) ...[
                  Expanded(
                    child: _buildCell(
                      context,
                      row * 7 + col,
                      leadingBlanks,
                      daysInMonth,
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate.year == _today.year &&
                      _selectedDate.month == _today.month &&
                      _selectedDate.day == _today.day
                  ? 'TODAY'
                  : '${_monthNames[_selectedDate.month - 1].toUpperCase()} ${_selectedDate.day}',
              style: AppTypography.labelCaps.copyWith(
                color: colors.textSecondary,
              ),
            ),
            Row(
              children: [
                if (selectedEvents.isNotEmpty)
                  TextButton(
                    onPressed: () => widget.onViewDateInTodo(_selectedDate),
                    child: const Text('View in TODO'),
                  ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline, color: colors.primary),
                  tooltip: 'Add task for this day',
                  onPressed: _addTaskForSelectedDate,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (selectedEvents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Nothing scheduled',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
          )
        else
          for (final task in selectedEvents) ...[
            _AgendaCard(task: task),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }

  Widget _buildCell(
    BuildContext context,
    int cellIndex,
    int leadingBlanks,
    int daysInMonth,
  ) {
    final colors = context.colors;
    final dayNumber = cellIndex - leadingBlanks + 1;
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 44);
    }

    final date = DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber);
    final isToday =
        date.year == _today.year &&
        date.month == _today.month &&
        date.day == _today.day;
    final isSelected =
        date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
    final hasEvent = _eventsByDate.containsKey(_dateOnly(date));

    return GestureDetector(
      onTap: () => setState(() => _selectedDate = date),
      child: SizedBox(
        height: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? colors.primaryContainer
                  : isToday
                  ? colors.surfaceContainerHigh
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '$dayNumber',
                  style: AppTypography.bodySm.copyWith(
                    color: isSelected ? colors.onPrimary : colors.textPrimary,
                    fontWeight: isToday || isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (hasEvent && !isSelected)
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.tertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.task});
  final TodoTask task;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final due = task.dueDate;
    final timeLabel = due != null && (due.hour != 0 || due.minute != 0)
        ? TimeOfDay.fromDateTime(due).format(context)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.standard),
              ),
              child: Icon(
                task.isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: task.isDone
                    ? colors.tertiary
                    : task.priority.color(colors),
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
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel == null
                        ? task.category
                        : '${task.category} · $timeLabel',
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
