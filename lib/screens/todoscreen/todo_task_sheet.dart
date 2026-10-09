// widgets/todo_task_sheet
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;
import '../../models/todo_task.dart';
import '../../services/alarm_sound_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

/// Opens the add/edit bottom sheet for a task. Pass [existing] to edit,
/// or omit it to create a new task. [initialDueDate] pre-fills the due
/// date on a *new* task (e.g. from Calendar's "+" on a selected day)
/// without making it look like an edit — it's ignored when [existing]
/// is given, since that already carries its own due date.
Future<void> showTodoTaskSheet(
  BuildContext context, {
  TodoTask? existing,
  DateTime? initialDueDate,
  required ValueChanged<TodoTask> onSave,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TodoTaskSheet(
      existing: existing,
      initialDueDate: initialDueDate,
      onSave: onSave,
      onDelete: onDelete,
    ),
  );
}

class _TodoTaskSheet extends StatefulWidget {
  const _TodoTaskSheet({
    this.existing,
    this.initialDueDate,
    required this.onSave,
    this.onDelete,
  });

  final TodoTask? existing;
  final DateTime? initialDueDate;
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
  // Multi-day fields — only meaningful (and only shown) when
  // _isMultiDay is on. Initialised from whether the task has an end at
  // all (not TodoTask.isMultiDay, which requires a later *calendar day*
  // and would silently drop the end of a same-day 9:00–17:00 task the
  // moment it was opened and saved).
  bool _isMultiDay = false;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  late bool _notificationEnabled;
  late bool _alarmEnabled;
  String? _titleError;
  String? _rangeError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _categoryController = TextEditingController(text: existing?.category ?? '');
    _priority = existing?.priority ?? TaskPriority.medium;
    _dueDate = existing?.dueDate ?? widget.initialDueDate;
    _dueTime = existing?.dueDate != null
        ? TimeOfDay.fromDateTime(existing!.dueDate!)
        : null;
    _isMultiDay = existing?.endDate != null;
    _endDate = existing?.endDate;
    _endTime = existing?.endDate != null
        ? TimeOfDay.fromDateTime(existing!.endDate!)
        : null;
    _notificationEnabled = existing?.notificationEnabled ?? false;
    _alarmEnabled = existing?.alarmEnabled ?? false;
    // The sound itself is a single app-wide setting (AlarmSoundService),
    // not per-task — just make sure it's loaded so the row below can
    // show the right name immediately instead of a blank first frame.
    AlarmSoundService.instance.load();
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
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _rangeError = null;
      });
    }
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
        _rangeError = null;
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

  Future<void> _pickEndDate() async {
    DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
    final base = dateOnly(_endDate ?? _dueDate ?? DateTime.now());
    // Can't end before the task starts. Clamp initialDate up to firstDate:
    // if the start date was moved past an already-picked end, base would
    // fall before firstDate and showDatePicker asserts on that.
    final first = dateOnly(_dueDate ?? DateTime(base.year - 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: base.isBefore(first) ? first : base,
      firstDate: first,
      lastDate: DateTime(base.year + 5),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _rangeError = null;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate ??= _dueDate ?? DateTime.now();
        _endTime = picked;
        _rangeError = null;
      });
    }
  }

  /// Same combine-date-and-time pattern as [_combinedDueDate], for the
  /// end side. Only meaningful when [_isMultiDay] is on.
  DateTime? get _combinedEndDate {
    if (_endDate == null) return null;
    if (_endTime == null) return _endDate;
    return DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endTime!.hour,
      _endTime!.minute,
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter a task title');
      return;
    }

    final dueDate = _combinedDueDate;

    // A multi-day task needs both ends, and the end has to come after
    // the start — catch that here instead of saving a task that shows
    // as ending before it begins (or one whose end silently vanished).
    if (_isMultiDay) {
      final start = dueDate;
      final end = _combinedEndDate;
      final problem = (start == null || end == null)
          ? 'Set both a start and an end for a multi-day task'
          : !end.isAfter(start)
          ? 'The end must be after the start'
          : null;
      if (problem != null) {
        setState(() => _rangeError = problem);
        return;
      }
    }

    // Only actually save an endDate when the switch is on — flipping it
    // off drops whatever end date/time was picked, same as clearing the
    // due date already drops the time.
    final endDate = _isMultiDay ? _combinedEndDate : null;
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
            endDate: endDate,
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
            endDate: endDate,
            clearEndDate: endDate == null,
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
                            ? (_isMultiDay ? 'Set start date' : 'Set due date')
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
                        _rangeError = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Multi-day task',
                  style: AppTypography.bodyMd.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'Spans from the date above to an end date',
                  style: AppTypography.bodySm.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                value: _isMultiDay,
                onChanged: (v) => setState(() {
                  _isMultiDay = v;
                  if (!v) _rangeError = null;
                }),
                activeThumbColor: colors.primary,
              ),
              if (_isMultiDay) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickEndDate,
                        icon: Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: colors.onSurface,
                        ),
                        label: Text(
                          _endDate == null
                              ? 'Set end date'
                              : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickEndTime,
                        icon: Icon(
                          Icons.access_time_outlined,
                          size: 16,
                          color: colors.onSurface,
                        ),
                        label: Text(
                          _endTime == null
                              ? 'Set time'
                              : _endTime!.format(context),
                        ),
                      ),
                    ),
                    if (_endDate != null)
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                        onPressed: () => setState(() {
                          _endDate = null;
                          _endTime = null;
                          _rangeError = null;
                        }),
                      ),
                  ],
                ),
                if (_rangeError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _rangeError!,
                      style: AppTypography.bodySm.copyWith(color: colors.error),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],

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
              if (_alarmEnabled) ...[
                const SizedBox(height: 4),
                _AlarmSoundRow(onTap: () => _showAlarmSoundSheet(context)),
                _SnoozeRow(onTap: () => _showSnoozePicker(context)),
              ],
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

/// Opens a compact picker for the app's alarm sound — the same choices
/// AlarmSoundCard offers in Settings (built-in sounds, phone ringtones,
/// upload), just reachable without leaving this sheet. The sound itself
/// is one app-wide setting (AlarmSoundService), not stored per task.
void _showAlarmSoundSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AlarmSoundSheet(),
  );
}

/// Opens a small picker for how long Snooze waits before an alarm rings
/// again — also one app-wide setting (AlarmSoundService.snoozeMinutes),
/// not stored per task, same as the sound above. Deliberately much
/// smaller than the sound sheet: just a row of duration chips, no
/// preview/upload/etc. to manage.
void _showSnoozePicker(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _SnoozePickerSheet(),
  );
}

/// The tappable "Alarm sound: <name>" row shown under the Alarm switch
/// when it's on. Rebuilds on its own via AnimatedBuilder so picking a
/// new sound in the sheet above updates this row immediately once it
/// closes, without the task sheet needing to know or care.
class _AlarmSoundRow extends StatelessWidget {
  const _AlarmSoundRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: AlarmSoundService.instance,
      builder: (context, _) {
        final sound = AlarmSoundService.instance.current;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.standard),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.alarm, size: 18, color: colors.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Alarm sound: ${sound.name}',
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: colors.outline),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The tappable "Snooze: <n> min" row shown under the Alarm switch, right
/// below _AlarmSoundRow. Same AnimatedBuilder-driven-by-the-service
/// pattern: the sheet it opens just calls
/// AlarmSoundService.instance.setSnoozeMinutes, and this row updates on
/// its own without the task sheet needing to know that happened.
class _SnoozeRow extends StatelessWidget {
  const _SnoozeRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: AlarmSoundService.instance,
      builder: (context, _) {
        final minutes = AlarmSoundService.instance.snoozeMinutes;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.standard),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.snooze_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Snooze: $minutes min',
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: colors.outline),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Small bottom sheet for picking the snooze duration — a row of chips
/// (snoozeOptions: 5/10/15/20/30 min) rather than a keyboard, same as
/// Priority above. Tapping a chip saves immediately and closes; there's
/// no separate "confirm" step, matching how _AlarmSoundSheet's built-in
/// sound chips also apply on tap.
class _SnoozePickerSheet extends StatelessWidget {
  const _SnoozePickerSheet();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: AlarmSoundService.instance,
      builder: (context, _) {
        final current = AlarmSoundService.instance.snoozeMinutes;
        return Container(
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
                'Snooze duration',
                style: AppTypography.bodyLg.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final minutes in snoozeOptions)
                    _SoundChip(
                      label: '$minutes min',
                      selected: minutes == current,
                      onTap: () async {
                        await AlarmSoundService.instance.setSnoozeMinutes(
                          minutes,
                        );
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Minimal alarm-sound picker: preview the current choice, pick a
/// built-in sound, choose a phone ringtone, upload a file, or reset to
/// default. Deliberately a subset of AlarmSoundCard's actions — full
/// management (and the BUILT-IN section header, etc.) stays in Settings;
/// this is a quick swap from mid-task-creation.
class _AlarmSoundSheet extends StatefulWidget {
  const _AlarmSoundSheet();

  @override
  State<_AlarmSoundSheet> createState() => _AlarmSoundSheetState();
}

class _AlarmSoundSheetState extends State<_AlarmSoundSheet> {
  late final Future<List<BuiltInSoundAsset>> _builtInSoundsFuture;

  @override
  void initState() {
    super.initState();
    _builtInSoundsFuture = AlarmSoundService.instance.listBuiltInSoundAssets();
  }

  Future<void> _handle(Future<({bool changed, String? error})> action) async {
    final result = await action;
    if (!mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final service = AlarmSoundService.instance;

    return Container(
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
        child: AnimatedBuilder(
          animation: service,
          builder: (context, _) {
            final sound = service.current;
            final previewing = service.isPreviewing;
            return Column(
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
                  'Alarm sound',
                  style: AppTypography.bodyLg.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sound.name,
                        style: AppTypography.bodyMd.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: previewing ? 'Stop preview' : 'Preview',
                      icon: Icon(
                        previewing
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        color: colors.primaryContainer,
                      ),
                      onPressed: () async {
                        if (previewing) {
                          await service.stopPreview();
                          return;
                        }
                        final error = await service.preview();
                        if (!mounted || error == null) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(error)));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    TextButton.icon(
                      onPressed: () => _handle(service.pickSystemRingtone()),
                      icon: const Icon(Icons.library_music_outlined, size: 18),
                      label: const Text('Choose from phone'),
                    ),
                    TextButton.icon(
                      onPressed: () => _handle(service.pickAndImport()),
                      icon: const Icon(Icons.upload_file_outlined, size: 18),
                      label: const Text('Upload sound'),
                    ),
                    if (sound.isCustom)
                      TextButton.icon(
                        onPressed: service.resetToDefault,
                        icon: const Icon(Icons.restore_outlined, size: 18),
                        label: const Text('Reset to default'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                FutureBuilder<List<BuiltInSoundAsset>>(
                  future: _builtInSoundsFuture,
                  builder: (context, snapshot) {
                    final sounds = snapshot.data;
                    if (sounds == null || sounds.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final builtIn in sounds)
                          _SoundChip(
                            label: builtIn.displayName,
                            selected:
                                sound.ownedByApp &&
                                sound.name == builtIn.displayName,
                            onTap: () =>
                                _handle(service.selectBuiltInAsset(builtIn)),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Same selected/unselected chip treatment used elsewhere (_PriorityChip
/// here, _FilterChip in todo_screen.dart, _BuiltInChip in
/// alarm_sound_card.dart) — kept as its own small copy rather than an
/// import since the one in alarm_sound_card.dart is private to that file.
/// Also reused by _SnoozePickerSheet above for the duration chips.
class _SoundChip extends StatelessWidget {
  const _SoundChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = colors.primaryContainer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.2)
              : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : colors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 14, color: accent),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: selected ? accent : colors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
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
