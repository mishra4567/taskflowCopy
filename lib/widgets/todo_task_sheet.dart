// widgets/todo_task_sheet
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;
import '../models/todo_task.dart';
import '../services/permission_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

/// Opens the add/edit bottom sheet for a task. Pass [existing] to edit,
/// or omit it to create a new task.
Future<void> showTodoTaskSheet(
  BuildContext context, {
  TodoTask? existing,
  required ValueChanged<TodoTask> onSave,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _TodoTaskSheet(existing: existing, onSave: onSave, onDelete: onDelete),
  );
}

class _TodoTaskSheet extends StatefulWidget {
  const _TodoTaskSheet({this.existing, required this.onSave, this.onDelete});

  final TodoTask? existing;
  final ValueChanged<TodoTask> onSave;
  final VoidCallback? onDelete;

  @override
  State<_TodoTaskSheet> createState() => _TodoTaskSheetState();
}

class _TodoTaskSheetState extends State<_TodoTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late TaskPriority _priority;
  DateTime? _dueDate;
  // Time is kept separate from _dueDate while editing (so the two pickers
  // are independent buttons) and only combined into one DateTime at save
  // time — TodoTask has no separate time field, dueDate carries both.
  TimeOfDay? _dueTime;
  late bool _notificationEnabled;
  late bool _alarmEnabled;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _categoryController = TextEditingController(text: existing?.category ?? '');
    _priority = existing?.priority ?? TaskPriority.medium;
    _dueDate = existing?.dueDate;
    _dueTime = existing?.dueDate != null
        ? TimeOfDay.fromDateTime(existing!.dueDate!)
        : null;
    _notificationEnabled = existing?.notificationEnabled ?? false;
    _alarmEnabled = existing?.alarmEnabled ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        // A time with no date attached isn't useful on its own — default
        // to today so "3:30 PM" always has a day to sit on.
        _dueDate ??= DateTime.now();
        _dueTime = picked;
      });
    }
  }

  /// The single DateTime that actually gets saved — date and time picked
  /// independently, combined here. Falls back to midnight when only a
  /// date was chosen, matching the previous date-only behavior.
  DateTime? get _combinedDueDate {
    if (_dueDate == null) return null;
    if (_dueTime == null) return _dueDate;
    return DateTime(
      _dueDate!.year,
      _dueDate!.month,
      _dueDate!.day,
      _dueTime!.hour,
      _dueTime!.minute,
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter a task title');
      return;
    }

    final dueDate = _combinedDueDate;
    final existing = widget.existing;
    final task = existing == null
        ? TodoTask(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
            category: _categoryController.text.trim().isEmpty
                ? 'General'
                : _categoryController.text.trim(),
            priority: _priority,
            dueDate: dueDate,
            notificationEnabled: _notificationEnabled,
            alarmEnabled: _alarmEnabled,
          )
        : existing.copyWith(
            title: title,
            category: _categoryController.text.trim().isEmpty
                ? 'General'
                : _categoryController.text.trim(),
            priority: _priority,
            dueDate: dueDate,
            clearDueDate: dueDate == null,
            notificationEnabled: _notificationEnabled,
            alarmEnabled: _alarmEnabled,
          );

    widget.onSave(task);
    Navigator.of(context).pop();
  }

  void _delete() {
    widget.onDelete?.call();
    Navigator.of(context).pop();
  }

  /// Turning the switch on asks for the OS permission first; turning it
  /// off never needs a permission check. If the person already said
  /// "don't ask again," `.request()` won't show a prompt at all, so we
  /// route to system settings instead of silently failing to enable it.
  Future<void> _onNotificationToggled(bool value) async {
    if (!value) {
      setState(() => _notificationEnabled = false);
      return;
    }
    final granted = await PermissionService.requestNotificationPermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _notificationEnabled = true);
      return;
    }
    final permanentlyDenied = await PermissionService.isPermanentlyDenied(
      Permission.notification,
    );
    if (!mounted) return;
    _showPermissionDeniedSnackBar(
      permanentlyDenied: permanentlyDenied,
      label: 'Notifications',
    );
  }

  Future<void> _onAlarmToggled(bool value) async {
    if (!value) {
      setState(() => _alarmEnabled = false);
      return;
    }
    final granted = await PermissionService.requestExactAlarmPermission();
    if (!mounted) return;
    if (granted) {
      setState(() => _alarmEnabled = true);
      return;
    }
    final permanentlyDenied = await PermissionService.isPermanentlyDenied(
      Permission.scheduleExactAlarm,
    );
    if (!mounted) return;
    _showPermissionDeniedSnackBar(
      permanentlyDenied: permanentlyDenied,
      label: 'Exact alarms',
    );
  }

  void _showPermissionDeniedSnackBar({
    required bool permanentlyDenied,
    required String label,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          permanentlyDenied
              ? '$label permission is off in Settings.'
              : '$label permission was declined.',
        ),
        action: permanentlyDenied
            ? SnackBarAction(
                label: 'Open Settings',
                onPressed: PermissionService.openSettings,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.container),
          ),
          border: Border.all(color: colors.borderSubtle),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.borderSubtle,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              Text(
                isEditing ? 'Edit task' : 'New task',
                style: AppTypography.bodyLg.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              TextField(
                controller: _titleController,
                style: AppTypography.bodyMd.copyWith(color: colors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Task title',
                  errorText: _titleError,
                ),
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              TextField(
                controller: _categoryController,
                style: AppTypography.bodyMd.copyWith(color: colors.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Category (e.g. Work)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'PRIORITY',
                style: AppTypography.labelCaps.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in TaskPriority.values)
                    _PriorityChip(
                      priority: p,
                      selected: _priority == p,
                      onTap: () => setState(() => _priority = p),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: colors.onSurface,
                      ),
                      label: Text(
                        _dueDate == null
                            ? 'Set due date'
                            : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: Icon(
                        Icons.access_time_outlined,
                        size: 16,
                        color: colors.onSurface,
                      ),
                      label: Text(
                        _dueTime == null
                            ? 'Set time'
                            : _dueTime!.format(context),
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      onPressed: () => setState(() {
                        _dueDate = null;
                        _dueTime = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Notification',
                  style: AppTypography.bodyMd.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                value: _notificationEnabled,
                onChanged: _onNotificationToggled,
                activeThumbColor: colors.primary,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Alarm',
                  style: AppTypography.bodyMd.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                value: _alarmEnabled,
                onChanged: _onAlarmToggled,
                activeThumbColor: colors.primary,
              ),
              const SizedBox(height: AppSpacing.md),

              Row(
                children: [
                  if (isEditing && widget.onDelete != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                          side: BorderSide(
                            color: colors.error.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  if (isEditing && widget.onDelete != null)
                    const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: Text(isEditing ? 'Save changes' : 'Add task'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final TaskPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = priority.color(colors);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? accent : colors.borderSubtle),
        ),
        child: Text(
          priority.label,
          style: AppTypography.bodySm.copyWith(
            color: selected ? accent : colors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
