// services/notification_service
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../data/app_database.dart';
import '../models/todo_task.dart';
import 'alarm_sound_service.dart';
import 'permission_service.dart';

/// Builds the alarm notification's Snooze/Dismiss actions for a given
/// snooze length. A top-level function rather than a class member (even
/// though NotificationService._scheduleAlarmEdge is the main caller) so
/// [handleAlarmAction] — which runs in an isolate with no access to
/// NotificationService.instance — can build an identical action list
/// when it re-schedules a snoozed alarm, from nothing but the minutes
/// value carried in the payload. The label can't be a compile-time
/// const anymore now that the duration is user-configurable (see
/// AlarmSoundService.snoozeMinutes), unlike the fixed-10-minute version
/// this replaces.
/// An unattended alarm keeps ringing every [AlarmSoundService.
/// snoozeMinutes] for up to this many minutes total before it just stops
/// on its own — a safety ceiling, not something the person configures.
/// Without one, a forgotten/undismissed alarm on a 5-minute interval
/// would otherwise keep firing indefinitely, forever.
const _autoRepeatWindowMinutes = 60;

/// Hard cap on how many occurrences get pre-scheduled per alarm batch,
/// regardless of interval (a 1-minute interval would otherwise want 60
/// occurrences for the window above). Also used as the fixed range
/// cancelled on Dismiss/Snooze — see [handleAlarmAction] and
/// NotificationService._cancelAlarmEdge — since the actual count used at
/// schedule time isn't necessarily known later if the snooze duration
/// setting changed in between.
const _maxAutoRepeatOccurrences = 24;

int _autoRepeatCountFor(int intervalMinutes) {
  final count = (_autoRepeatWindowMinutes / intervalMinutes).ceil();
  return count.clamp(1, _maxAutoRepeatOccurrences);
}

/// Schedules a whole batch of identical alarm occurrences, [intervalMinutes]
/// apart, starting at [start] — this is what makes an unattended alarm
/// keep ringing on its own every few minutes instead of showing once and
/// going silent. Each occurrence is a fully independent system alarm (id
/// baseId, baseId+1, ... baseId+count-1), so nothing needs to run in
/// between them for the repeat to happen. A top-level function (not a
/// NotificationService method) so [handleAlarmAction] — running in a
/// background isolate with no access to NotificationService.instance —
/// can call it too, when re-starting the batch after a snooze.
Future<void> _scheduleAutoRepeatBatch({
  required FlutterLocalNotificationsPlugin plugin,
  required int baseId,
  required String title,
  required String body,
  required String channelId,
  required String soundUri,
  required int intervalMinutes,
  required tz.TZDateTime start,
}) async {
  final count = _autoRepeatCountFor(intervalMinutes);
  final payload = jsonEncode({
    'title': title,
    'body': body,
    'channelId': channelId,
    'soundUri': soundUri,
    'snoozeMinutes': intervalMinutes,
    'baseId': baseId,
  });

  for (var i = 0; i < count; i++) {
    final when = start.add(Duration(minutes: intervalMinutes * i));
    await plugin.zonedSchedule(
      id: baseId + i,
      title: title,
      body: body,
      scheduledDate: when,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Alarms',
          channelDescription: 'Ringing alarms for tasks',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          playSound: true,
          sound: UriAndroidNotificationSound(soundUri),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          timeoutAfter: NotificationService._alarmTimeoutMs,
          actions: _alarmActionsFor(intervalMinutes),
        ),
        iOS: const DarwinNotificationDetails(
          sound: 'default',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}

/// Cancels every id in a batch's fixed range — used whenever an alarm
/// needs to stop entirely (task edited/completed/deleted, or an explicit
/// Dismiss/Snooze), so no occurrence scheduled further out than the one
/// actually interacted with is ever left silently pending.
Future<void> _cancelAutoRepeatBatch(
  FlutterLocalNotificationsPlugin plugin,
  int baseId,
) async {
  for (var i = 0; i < _maxAutoRepeatOccurrences; i++) {
    await plugin.cancel(id: baseId + i);
  }
}

List<AndroidNotificationAction> _alarmActionsFor(int snoozeMinutes) {
  return [
    AndroidNotificationAction(
      'snooze',
      'Snooze ${snoozeMinutes}m',
      showsUserInterface: false,
      cancelNotification: true,
    ),
    const AndroidNotificationAction(
      'dismiss',
      'Dismiss',
      showsUserInterface: false,
      cancelNotification: true,
    ),
  ];
}

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

/// Which edge of a task a notification/alarm is for. A simple task only
/// ever uses [single]; a task with an end uses [start] and [end], so its
/// two reminders get distinct ids instead of overwriting each other.
enum _Edge { single, start, end }

/// Schedules and cancels the reminder notification(s) and alarm(s) tied
/// to a task.
///
/// A task has two independent switches (todo_task_sheet.dart):
/// - Notification: a normal, quiet reminder on the default channel.
/// - Alarm: a loud, full-screen ringing alarm on its own channel, using
///   whatever sound is chosen in Settings (AlarmSoundService) — the
///   phone's default alarm tone unless the user uploaded one.
///
/// Both can be on for the same task; they use separate notification ids
/// (see [_notificationId]/[_alarmId]) so toggling one never touches the
/// other's schedule.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'taskflow_tasks_channel';
  static const _channelName = 'Task Reminders';
  static const _channelDescription = 'Reminders for tasks with a due date';

  /// How long a ringing alarm notification stays up (and audible) before
  /// Android auto-dismisses it if the user never taps it — matches
  /// AlarmSoundService's own preview length being short, so a forgotten
  /// alarm doesn't ring forever in the background.
  static const _alarmTimeoutMs = 60000;

  /// A single, reusable Dismiss-only action — for the quiet Notification
  /// channel, which (unlike Alarm) never snoozes. showsUserInterface:
  /// false keeps the tap from launching the app; cancelNotification:
  /// true removes it. No payload needed for this one: handleAlarmAction
  /// only ever acts on actionId 'snooze', so a plain dismiss here is a
  /// total no-op beyond the OS removing the notification itself.
  static const _dismissOnlyAction = <AndroidNotificationAction>[
    AndroidNotificationAction(
      'dismiss',
      'Dismiss',
      showsUserInterface: false,
      cancelNotification: true,
    ),
  ];

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
      // Same handler for both: handleAlarmAction is self-contained (reads
      // everything it needs from the payload, touches no app/isolate
      // state) so it works identically whether the tap happened with the
      // app alive (onDidReceiveNotificationResponse, same isolate) or
      // fully backgrounded/killed (onDidReceiveBackgroundNotificationResponse,
      // a separate isolate — see that function's doc for why).
      onDidReceiveNotificationResponse: handleAlarmAction,
      onDidReceiveBackgroundNotificationResponse: handleAlarmAction,
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

    // Loads the saved alarm-sound choice (or leaves the default) before
    // anything might try to schedule an alarm.
    await AlarmSoundService.instance.load();
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

  /// Alarm ids live in a disjoint range from [_notificationId]'s (top bit
  /// forced on via the large odd XOR mask below is what keeps the two id
  /// spaces from ever colliding for the same task), so the bell
  /// reminder and the ringing alarm for the same task never fight over
  /// one slot.
  int _alarmId(String taskId, _Edge edge) {
    final base = (taskId.hashCode ^ 0x5a5a5a5a) & 0x3fffffff;
    final withRange = base | 0x40000000;
    switch (edge) {
      case _Edge.single:
        return withRange;
      case _Edge.start:
        return -withRange;
      case _Edge.end:
        return -(withRange ^ 0x0f0f0f0f);
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

  // ---------------------------------------------------------------------
  // Notifications (quiet reminder, default channel)
  // ---------------------------------------------------------------------

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
      // Lets handleAlarmAction's Dismiss handling cancel this by an id it
      // read directly from the payload, rather than trusting
      // NotificationResponse.id to be populated — see handleAlarmAction's
      // doc for why that turned out not to be reliable enough on its own.
      payload: jsonEncode({'notificationId': id}),
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

  // ---------------------------------------------------------------------
  // Alarms (loud, ringing, own channel/sound — the Alarm switch)
  // ---------------------------------------------------------------------

  /// Android locks a notification channel's sound the moment the channel
  /// is first created — recreating the channel with the same id but a
  /// new sound is silently ignored by the OS. So each alarm-sound choice
  /// gets its own channel id (derived from the sound's uri), and
  /// switching sounds in Settings means switching channels, not mutating
  /// one shared channel.
  String _alarmChannelId(String soundUri) =>
      'taskflow_alarm_channel_${soundUri.hashCode & 0x7fffffff}';

  Future<void> _ensureAlarmChannel(AlarmSound sound) async {
    final channel = AndroidNotificationChannel(
      _alarmChannelId(sound.uri),
      'Alarms',
      description: 'Ringing alarms for tasks',
      importance: Importance.max,
      playSound: true,
      sound: UriAndroidNotificationSound(sound.uri),
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Schedules (or reschedules) the ringing alarm(s) for [task], mirroring
  /// [scheduleTaskNotification]'s single-vs-start/end shape. Always reads
  /// the *current* AlarmSoundService.instance.current at call time, so
  /// editing a task after changing the sound in Settings picks up the
  /// new sound automatically — nothing needs to re-schedule proactively
  /// when the sound changes.
  Future<void> scheduleTaskAlarm(TodoTask task) async {
    if (!await PermissionService.requestNotificationPermission()) return;
    await ensureInitialized();
    final sound = AlarmSoundService.instance.current;
    await _ensureAlarmChannel(sound);

    if (_hasEnd(task)) {
      await _cancelAlarmEdge(task.id, _Edge.single);
      await _scheduleAlarmEdge(
        task,
        _Edge.start,
        task.dueDate,
        sound,
        label: 'Starting',
      );
      await _scheduleAlarmEdge(
        task,
        _Edge.end,
        task.endDate,
        sound,
        label: 'Ending',
      );
    } else {
      await _cancelAlarmEdge(task.id, _Edge.start);
      await _cancelAlarmEdge(task.id, _Edge.end);
      await _scheduleAlarmEdge(task, _Edge.single, task.dueDate, sound);
    }
  }

  Future<void> _scheduleAlarmEdge(
    TodoTask task,
    _Edge edge,
    DateTime? when,
    AlarmSound sound, {
    String? label,
  }) async {
    final id = _alarmId(task.id, edge);
    if (when == null) {
      await _cancelAutoRepeatBatch(_plugin, id);
      return;
    }

    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
      await _cancelAutoRepeatBatch(_plugin, id);
      return;
    }

    final title = label == null
        ? '⏰ ${task.title}'
        : '⏰ ${task.title} — $label';
    final body = _bodyFor(task);
    final channelId = _alarmChannelId(sound.uri);
    // Read fresh at schedule time, not cached — editing a task after
    // changing the snooze/repeat interval in Settings should pick up the
    // new value automatically, same as AlarmSoundService.instance.current
    // already does for the sound. This same value is now both "how long
    // Snooze waits" AND "how often an unattended alarm re-rings on its
    // own" — one setting, two uses, rather than a second number to manage.
    final intervalMinutes = AlarmSoundService.instance.snoozeMinutes;

    // Clear out anything previously scheduled under this id range before
    // laying down a fresh batch — otherwise editing a task's time would
    // leave the *old* batch's later occurrences still pending alongside
    // the new ones.
    await _cancelAutoRepeatBatch(_plugin, id);
    await _scheduleAutoRepeatBatch(
      plugin: _plugin,
      baseId: id,
      title: title,
      body: body,
      channelId: channelId,
      soundUri: sound.uri,
      intervalMinutes: intervalMinutes,
      start: scheduled,
    );
  }

  Future<void> _cancelAlarmEdge(String taskId, _Edge edge) =>
      _cancelAutoRepeatBatch(_plugin, _alarmId(taskId, edge));

  Future<void> cancelTaskAlarm(String taskId) async {
    await ensureInitialized();
    await _cancelAlarmEdge(taskId, _Edge.single);
    await _cancelAlarmEdge(taskId, _Edge.start);
    await _cancelAlarmEdge(taskId, _Edge.end);
  }

  /// Re-schedules every pending task alarm using whatever sound is
  /// currently chosen in AlarmSoundService. Necessary because a
  /// notification channel's sound is locked in at creation — simply
  /// updating AlarmSoundService.instance.current does NOT retroactively
  /// change the channel an already-scheduled alarm is tied to, so it
  /// would otherwise keep ringing (or staying silent) on whatever sound
  /// was current when it was first scheduled. Call this right after the
  /// chosen sound changes (see AlarmSoundCard's upload/pick/reset
  /// handlers) so every in-flight alarm actually moves onto the new
  /// channel instead of silently staying on the old one.
  Future<void> rescheduleAllAlarms() async {
    await ensureInitialized();
    final bundles = await AppDatabase.instance.getAllTodosWithSubtasks();
    for (final bundle in bundles) {
      final task = TodoTask.fromBundle(bundle);
      final shouldAlarm =
          task.alarmEnabled && task.dueDate != null && !task.isDone;
      if (shouldAlarm) {
        await scheduleTaskAlarm(task);
      }
    }
  }

  // ---------------------------------------------------------------------
  // Debug helpers
  // ---------------------------------------------------------------------

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

  /// Debug helper: one-off ringing alarm [seconds] from now, using
  /// whatever sound is currently chosen in Settings, through the real
  /// scheduleTaskAlarm path.
  Future<void> scheduleTestAlarm({int seconds = 10}) async {
    final now = DateTime.now();
    final task = TodoTask(
      id: '__test_alarm__',
      title: 'Test alarm',
      category: 'Test',
      priority: TaskPriority.medium,
      dueDate: now.add(Duration(seconds: seconds)),
      alarmEnabled: true,
    );
    await scheduleTaskAlarm(task);
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
          actions: _dismissOnlyAction,
        );
    }
  }
}

/// Handles a tap on the alarm notification's Snooze/Dismiss buttons.
///
/// Must be top-level (not a method) and marked @pragma('vm:entry-point')
/// because Android can invoke this in a fresh background isolate — with
/// none of this app's normal state — when the person taps an action
/// while the app is backgrounded or fully killed. NotificationService.
/// instance, AlarmSoundService, AppDatabase: none of that exists in that
/// isolate. So this touches nothing but the plugin itself and whatever
/// [response.payload] carries (set when the alarm was first scheduled —
/// see _scheduleAlarmEdge), which is enough to re-ring an identical
/// alarm [NotificationService._snoozeMinutes] later without needing to
/// know anything about the task that created it.
///
/// Used for both onDidReceiveNotificationResponse (foreground/same-
/// isolate) and onDidReceiveBackgroundNotificationResponse (background
/// isolate) — being payload-only rather than instance-based means the
/// exact same function is correct for either case, so there's only one
/// implementation to keep in sync.
@pragma('vm:entry-point')
Future<void> handleAlarmAction(NotificationResponse response) async {
  final actionId = response.actionId;
  // A plain tap on the notification body (actionId null) just opens the
  // app via the plugin's own default handling — nothing for this
  // function to do. Anything other than the two buttons this alarm
  // actually has is also a no-op.
  if (actionId != 'snooze' && actionId != 'dismiss') return;

  final payload = response.payload;
  if (payload == null) return; // nothing to act on either way

  Map<String, dynamic> data;
  try {
    data = jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return; // malformed payload — nothing safe to act on
  }

  final plugin = FlutterLocalNotificationsPlugin();

  // The quiet Notification channel's Dismiss carries {'notificationId':
  // id} — no auto-repeat batch, nothing to snooze, just cancel that one
  // id directly. Reading the id from the payload (set by us, at schedule
  // time) rather than NotificationResponse.id is deliberate: id wasn't
  // reliably populated for this path, which is what made the first
  // version of this fix not actually work.
  final notificationId = data['notificationId'] as int?;
  if (notificationId != null) {
    if (actionId == 'dismiss') {
      await plugin.cancel(id: notificationId);
    }
    return;
  }

  final baseId = data['baseId'] as int?;
  if (baseId == null) return;
  // Whichever button was tapped, every remaining occurrence in this
  // alarm's auto-repeat batch needs to stop — otherwise Dismiss would
  // only hide the notification in front of you while the next one
  // further out still rings a few minutes later regardless.
  await _cancelAutoRepeatBatch(plugin, baseId);

  if (actionId == 'dismiss') return; // fully stopped — nothing further

  // snooze: start a brand-new auto-repeating batch further out, same
  // shape as the original (same title/sound/interval), just later.
  final title = data['title'] as String?;
  final body = data['body'] as String?;
  final channelId = data['channelId'] as String?;
  final soundUri = data['soundUri'] as String?;
  // Falls back to AlarmSoundService's own default if an older payload
  // (scheduled before this field existed) is ever snoozed — unlikely in
  // practice, but cheap insurance against a null-check crash in a
  // background isolate, where there's no UI to show an error from.
  final intervalMinutes = data['snoozeMinutes'] as int? ?? 10;
  if (title == null || body == null || channelId == null || soundUri == null) {
    return;
  }

  tz_data.initializeTimeZones();
  try {
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    final zoneName =
        _legacyTimezoneAliases[localTimezone.identifier] ??
        localTimezone.identifier;
    tz.setLocalLocation(tz.getLocation(zoneName));
  } catch (_) {
    // Worst case this runs in UTC — wrong by a few hours is still far
    // better than the snooze silently failing outright.
  }

  final start = tz.TZDateTime.now(
    tz.local,
  ).add(Duration(minutes: intervalMinutes));

  await _scheduleAutoRepeatBatch(
    plugin: plugin,
    baseId: baseId,
    title: title,
    body: body,
    channelId: channelId,
    soundUri: soundUri,
    intervalMinutes: intervalMinutes,
    start: start,
  );
}
