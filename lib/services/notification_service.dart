// services/notification_service
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/todo_task.dart';
import 'permission_service.dart';

/// Some Android devices/OEMs still report pre-2005 IANA zone names that
/// were merged into a canonical zone (e.g. "Asia/Calcutta" ->
/// "Asia/Kolkata"). `latest.dart`'s data set is the current, much
/// smaller one and doesn't carry those deprecated aliases — pulling in
/// `latest_all.dart` to cover a handful of names roughly doubles the
/// synchronous parse cost at startup, so a small manual map is the
/// cheaper fix. Extend this if another deprecated name turns up.
const _legacyTimezoneAliases = {
  'Asia/Calcutta': 'Asia/Kolkata',
  'Asia/Saigon': 'Asia/Ho_Chi_Minh',
  'Asia/Rangoon': 'Asia/Yangon',
  'Asia/Katmandu': 'Asia/Kathmandu',
  'Europe/Kiev': 'Europe/Kyiv',
};

/// How a scheduled notification looks. Only [standard] exists today —
/// this enum is the extension point for "choose a design" later: each
/// new case gets a branch in [_androidDetailsFor] below, and a settings
/// screen can eventually just store which one to pass in here. Nothing
/// about scheduling, permissions, or the call sites in todo_screen.dart /
/// quick_add_sheet.dart needs to change when that's added.
enum NotificationStyle { standard }

/// Which edge of a task a notification is for. A simple task only ever
/// uses [single]; a task with an end uses [start] and [end], so its two
/// reminders get distinct ids instead of overwriting each other.
enum _Edge { single, start, end }

/// Schedules and cancels the reminder notification(s) tied to a task.
/// A simple task gets one, at dueDate. A task with an endDate after its
/// dueDate gets two — "Starting" at dueDate, "Ending" at endDate. This
/// is the Notification switch in todo_task_sheet.dart — the separate
/// Alarm switch is permission-gated already (permission_service.dart)
/// but doesn't fire anything yet; exact-alarm delivery is a bigger
/// follow-up (needs its own scheduling path, likely
/// android_alarm_manager_plus, since a local notification isn't really
/// an "alarm").
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'taskflow_tasks_channel';
  static const _channelName = 'Task Reminders';
  static const _channelDescription = 'Reminders for tasks with a due date';

  Future<void>? _initFuture;

  /// Startup entry point (call from main). Does NOT do the work itself —
  /// queues it for right after the first frame paints
  /// (addPostFrameCallback), because tz_data.initializeTimeZones() is
  /// pure synchronous CPU work with no internal await points: calling
  /// it from an "unawaited" async function does not help, since it
  /// still runs to completion before that function's first real await.
  /// Without this deferral it blocks the UI thread during the very
  /// first frames, which is what was causing the multi-second/skipped-
  /// frame startup freeze.
  ///
  /// Note this returns immediately — it does NOT mean setup has
  /// finished. Anything that needs the plugin/timezone ready must
  /// await [ensureInitialized] instead.
  Future<void> init() async {
    if (_initFuture != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => ensureInitialized());
  }

  /// Resolves once setup has actually completed. Safe to call any number
  /// of times, from anywhere, before or after [init]'s deferred callback
  /// fires — the work runs exactly once and every caller shares the same
  /// future. A failed attempt clears itself so a later call can retry.
  Future<void> ensureInitialized() => _initFuture ??= _guardedInit();

  Future<void> _guardedInit() async {
    try {
      await _doInit();
    } catch (_) {
      _initFuture = null;
      rethrow;
    }
  }

  Future<void> _doInit() async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    final zoneName =
        _legacyTimezoneAliases[localTimezone.identifier] ??
        localTimezone.identifier;
    tz.setLocalLocation(tz.getLocation(zoneName));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Deterministic per-task, per-edge notification id, so scheduling the
  /// same task twice (e.g. editing it) replaces rather than duplicates.
  /// [_Edge.single] is exactly the id a plain task has always had, so
  /// notifications scheduled before multi-day tasks existed still get
  /// replaced/cancelled correctly. Start and end use negative ids (the
  /// plugin accepts any 32-bit int), which can never collide with a
  /// single id, and differ from each other for the same task.
  int _notificationId(String taskId, _Edge edge) {
    final base = taskId.hashCode & 0x7fffffff;
    switch (edge) {
      case _Edge.single:
        return base;
      case _Edge.start:
        return ~base;
      case _Edge.end:
        return ~(base ^ 0x40000000);
    }
  }

  /// A task gets a separate "ending" reminder when it has an end that's
  /// actually after its start. Deliberately not TodoTask.isMultiDay —
  /// that only counts an end on a *later calendar day*, so a same-day
  /// 9:00–17:00 task would silently lose its end reminder.
  bool _hasEnd(TodoTask task) {
    final start = task.dueDate;
    final end = task.endDate;
    return start != null && end != null && end.isAfter(start);
  }

  /// Schedules (or reschedules) the reminder(s) for [task]. A simple task
  /// gets one notification at dueDate; a task with an end gets
  /// "— Starting" at dueDate and "— Ending" at endDate. Switching a task
  /// between the two shapes always cancels the slots that no longer
  /// apply, so no stale notification survives the change. A missing or
  /// already-passed date cancels that slot rather than leaving an older
  /// schedule in place — callers don't need to check either themselves.
  Future<void> scheduleTaskNotification(
    TodoTask task, {
    NotificationStyle style = NotificationStyle.standard,
  }) async {
    if (!await PermissionService.requestNotificationPermission()) return;
    await ensureInitialized();
    if (_hasEnd(task)) {
      await _cancelEdge(task.id, _Edge.single);
      await _scheduleEdge(
        task,
        _Edge.start,
        task.dueDate,
        style,
        label: 'Starting',
      );
      await _scheduleEdge(
        task,
        _Edge.end,
        task.endDate,
        style,
        label: 'Ending',
      );
    } else {
      await _cancelEdge(task.id, _Edge.start);
      await _cancelEdge(task.id, _Edge.end);
      await _scheduleEdge(task, _Edge.single, task.dueDate, style);
    }
  }

  Future<void> _scheduleEdge(
    TodoTask task,
    _Edge edge,
    DateTime? when,
    NotificationStyle style, {
    String? label,
  }) async {
    final id = _notificationId(task.id, edge);
    if (when == null) {
      await _plugin.cancel(id: id);
      return;
    }

    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      await _plugin.cancel(id: id);
      return;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: label == null ? task.title : '${task.title} — $label',
      body: _bodyFor(task),
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: _androidDetailsFor(style),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _cancelEdge(String taskId, _Edge edge) =>
      _plugin.cancel(id: _notificationId(taskId, edge));

  Future<void> cancelTaskNotification(String taskId) async {
    await ensureInitialized();
    await _cancelEdge(taskId, _Edge.single);
    await _cancelEdge(taskId, _Edge.start);
    await _cancelEdge(taskId, _Edge.end);
  }

  static const _testNotificationId = 0x7ffffff0;

  /// Debug helper: one-off notification [seconds] from now, through the
  /// same permission/channel/timezone/exact-alarm path a real task
  /// reminder uses, without creating a task and waiting for a due time.
  Future<void> scheduleTestNotification({int seconds = 10}) async {
    if (!await PermissionService.requestNotificationPermission()) return;
    await ensureInitialized();
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      id: _testNotificationId,
      title: 'Test notification',
      body: 'If you can read this, scheduled notifications work.',
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: _androidDetailsFor(NotificationStyle.standard),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Debug helper: schedules a throwaway multi-day task through the real
  /// scheduleTaskNotification path — a "Starting" notification 15s from
  /// now and an "Ending" one 45s from now — to verify both edges fire
  /// with distinct ids/titles. Not persisted anywhere.
  Future<void> scheduleTestRangedNotifications() async {
    final now = DateTime.now();
    final task = TodoTask(
      id: '__test_ranged__',
      title: 'Test multi-day task',
      category: 'Test',
      priority: TaskPriority.medium,
      dueDate: now.add(const Duration(seconds: 15)),
      endDate: now.add(const Duration(seconds: 45)),
      notificationEnabled: true,
    );
    await scheduleTaskNotification(task);
  }

  String _bodyFor(TodoTask task) => '${task.category} · ${task.priority.label}';

  /// Only one style today; future styles (big text, big picture, custom
  /// layout via a plugin's platform-channel data, etc.) each add a case
  /// here without touching anything that calls this service.
  AndroidNotificationDetails _androidDetailsFor(NotificationStyle style) {
    switch (style) {
      case NotificationStyle.standard:
        return AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        );
    }
  }
}
