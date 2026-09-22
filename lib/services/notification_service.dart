// services/notification_service
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/todo_task.dart';

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

/// Schedules and cancels the reminder notification tied to a task's due
/// date. This is the Notification switch in todo_task_sheet.dart — the
/// separate Alarm switch is permission-gated already (permission_service
/// .dart) but doesn't fire anything yet; exact-alarm delivery is a
/// bigger follow-up (needs its own scheduling path, likely
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

  bool _initialized = false;

  /// Call once at startup. Does NOT await the heavy work directly —
  /// schedules it for right after the first frame paints
  /// (addPostFrameCallback), because tz_data.initializeTimeZones() is
  /// pure synchronous CPU work with no internal await points: calling
  /// it from an "unawaited" async function does not help, since it
  /// still runs to completion before that function's first real await.
  /// Without this deferral it blocks the UI thread during the very
  /// first frames, which is what was causing the multi-second/skipped-
  /// frame startup freeze.
  Future<void> init() async {
    if (_initialized) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initInternal());
  }

  Future<void> _initInternal() async {
    if (_initialized) return;

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

    _initialized = true;
  }

  /// Deterministic per-task notification id, so scheduling the same
  /// task twice (e.g. editing it) replaces rather than duplicates.
  int _notificationId(String taskId) => taskId.hashCode & 0x7fffffff;

  /// Schedules (or reschedules) the reminder for [task]. No-ops if the
  /// task has no due date, or the due date/time has already passed —
  /// callers don't need to check either condition themselves.
  Future<void> scheduleTaskNotification(
    TodoTask task, {
    NotificationStyle style = NotificationStyle.standard,
  }) async {
    final due = task.dueDate;
    if (due == null) return;

    final scheduled = tz.TZDateTime.from(due, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id: _notificationId(task.id),
      title: task.title,
      body: _bodyFor(task),
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: _androidDetailsFor(style),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelTaskNotification(String taskId) =>
      _plugin.cancel(id: _notificationId(taskId));

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
