// services/permission_service
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// Requests the OS permissions the app needs. Started with Notification
/// and Alarm (used by todo_task_sheet.dart's switches) — kept as one
/// general-purpose service rather than a per-feature file, so any future
/// permission (contacts, calendar sync, etc.) has a single place to live.
class PermissionService {
  PermissionService._();

  /// POST_NOTIFICATIONS on Android 13+, the standard prompt on iOS.
  /// Android <13 has no runtime notification permission, so this
  /// short-circuits to true there.
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Android 12+ requires a *separate* grant for exact-time alarms,
  /// given via a system settings screen rather than an in-app dialog
  /// (that's `Permission.scheduleExactAlarm`'s prompt on the plugin
  /// side). iOS has no equivalent concept, so this is always true there.
  static Future<bool> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    final status = await Permission.scheduleExactAlarm.request();
    return status.isGranted;
  }

  /// True once the person has said "don't ask again" (Android) or
  /// turned it off in Settings (iOS) — further `.request()` calls won't
  /// show a prompt, so callers should route to app settings instead.
  static Future<bool> isPermanentlyDenied(Permission permission) async {
    return permission.isPermanentlyDenied;
  }

  static Future<void> openSettings() => openAppSettings();
}
