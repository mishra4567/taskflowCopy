import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/data/app_database.dart';
import 'package:taskflow/models/todo_task.dart';
import 'package:taskflow/services/spend/expense_refresh_bus.dart';
import 'package:taskflow/services/notification_service.dart';
import 'package:taskflow/services/todo_refresh_bus.dart';

import '../api/api_client.dart';
import '../api/device_session.dart';
import '../api/sync_api.dart';
import 'sync_local_store.dart';

enum SyncOutcome { done, busy, notSignedIn, failed }

class SyncService extends ChangeNotifier {
  SyncService._();

  static final SyncService instance = SyncService._();

  static const _pushedKey = 'taskflow_sync_pushed_until';
  static const _cursorKey = 'taskflow_sync_cursor';
  static const _lastSyncKey = 'taskflow_sync_last_at';

  static const int _chunk = 200;
  static const int _pullLimit = 500;

  static const Duration _pushPullDelay = Duration(seconds: 5);

  bool _syncing = false;
  bool get isSyncing => _syncing;

  DateTime? lastSyncedAt;
  String? lastError;

  String phase = '';
  double? progress;

  int lastSent = 0;
  int lastReceived = 0;

  Future<void> loadCached() async {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt(_lastSyncKey);

    if (at != null) {
      lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(at * 1000);
    }

    notifyListeners();
  }

  /// Clear this account's sync position on sign-out.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_pushedKey);
    await prefs.remove(_cursorKey);
    await prefs.remove(_lastSyncKey);

    lastSyncedAt = null;
    lastError = null;
    lastSent = 0;
    lastReceived = 0;

    notifyListeners();
  }

  /// Reads the cursor and migrates the old string preference if necessary.
  Future<int> _readCursor(SharedPreferences prefs) async {
    final raw = prefs.get(_cursorKey);

    if (raw is int) return raw;

    if (raw is String) {
      final parsed = int.tryParse(raw) ?? 0;
      await prefs.setInt(_cursorKey, parsed);
      return parsed;
    }

    return 0;
  }

  Future<SyncOutcome> syncNow() async {
    if (_syncing) return SyncOutcome.busy;

    if (!await DeviceSession.instance.isSignedIn) {
      return SyncOutcome.notSignedIn;
    }

    _syncing = true;
    lastError = null;
    lastSent = 0;
    lastReceived = 0;

    phase = 'Preparing to sync…';
    progress = null;
    notifyListeners();

    final started = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();

      final pushedUntil = prefs.getInt(_pushedKey) ?? 0;

      // ================================================================
      // PHASE 1: PUSH
      // ================================================================

      phase = 'Checking for local changes…';
      progress = null;
      notifyListeners();

      final changes = await SyncLocalStore.collectChanges(
        DateTime.fromMillisecondsSinceEpoch(pushedUntil * 1000),
      );

      var pushedCount = 0;

      if (changes.isNotEmpty) {
        phase = 'Preparing ${changes.length} local changes…';
        progress = 0;
        notifyListeners();

        for (var i = 0; i < changes.length; i += _chunk) {
          final end = i + _chunk < changes.length ? i + _chunk : changes.length;

          final batch = changes.sublist(i, end);

          // Convert to Laravel's exact grouped snake_case format.
          // Contact encryption happens during this conversion.
          final grouped = await SyncLocalStore.toLaravelChanges(batch);

          phase = 'Uploading changes (${end}/${changes.length})…';
          progress = i / changes.length;
          notifyListeners();

          final response = await SyncApi.instance.push(grouped);

          final applied = response['applied'];
          if (applied is num) {
            pushedCount += applied.toInt();
          } else {
            pushedCount += batch.length;
          }

          final rejected = response['rejected'];
          if (rejected is List && rejected.isNotEmpty) {
            debugPrint('Laravel rejected sync records: $rejected');
          }

          debugPrint('Laravel push response: $response');

          progress = end / changes.length;
          notifyListeners();
        }
      } else {
        phase = 'No local changes to upload.';
        progress = 1;
        notifyListeners();
      }

      // ================================================================
      // WAIT 5 SECONDS
      // ================================================================

      phase = 'Upload complete. Waiting 5 seconds before download…';
      progress = null;
      notifyListeners();

      await Future<void>.delayed(_pushPullDelay);

      // ================================================================
      // PHASE 2: PULL
      // ================================================================

      phase = 'Downloading changes from your other devices…';
      progress = null;
      notifyListeners();

      var cursor = await _readCursor(prefs);

      final resync = <String>{};
      final removed = <String>{};

      var taskCount = 0;
      var expenseCount = 0;
      var contactCount = 0;

      while (true) {
        final previousCursor = cursor;

        final page = await SyncApi.instance.pull(cursor, limit: _pullLimit);

        // A malformed row must not be silently skipped while advancing
        // the cursor. Fix the data/parser and retry this same page.
        if (page.skipped > 0) {
          throw FormatException(
            '${page.skipped} malformed record(s) were returned by '
            'the server. Cursor was not advanced.',
          );
        }

        if (page.records.isNotEmpty) {
          phase = 'Applying ${page.records.length} downloaded changes…';
          progress = null;
          notifyListeners();

          final result = await SyncLocalStore.apply(page.records);

          // This also protects against a local validation failure.
          if (result.skipped > 0) {
            throw StateError(
              '${result.skipped} downloaded record(s) could not be '
              'applied. Cursor was not advanced.',
            );
          }

          resync.addAll(result.tasksToResync);
          removed.addAll(result.tasksRemoved);

          taskCount += result.tasks;
          expenseCount += result.expenses;
          contactCount += result.contacts;
        }

        // Save this page's cursor only after successful application.
        cursor = page.cursor;
        await prefs.setInt(_cursorKey, cursor);

        if (!page.hasMore) break;

        if (cursor <= previousCursor) {
          throw StateError('Sync pagination did not advance its cursor.');
        }
      }

      // ================================================================
      // PHASE 3: SAVE SUCCESSFUL SYNC POSITION
      // ================================================================

      // One second back because collection uses >=.
      // This also catches edits made during the sync operation.
      await prefs.setInt(
        _pushedKey,
        started.millisecondsSinceEpoch ~/ 1000 - 1,
      );

      final now = DateTime.now();

      await prefs.setInt(_lastSyncKey, now.millisecondsSinceEpoch ~/ 1000);

      lastSyncedAt = now;
      lastSent = pushedCount;
      lastReceived = taskCount + contactCount + expenseCount;

      // ================================================================
      // PHASE 4: REFRESH LOCAL UI AND REMINDERS
      // ================================================================

      phase = 'Updating local data and reminders…';
      progress = null;
      notifyListeners();

      if (taskCount > 0) {
        TodoRefreshBus.notify();
      }

      if (expenseCount > 0) {
        ExpenseRefreshBus.notify();
      }

      // Contacts are read through the contacts table's Drift stream.
      await _fixReminders(resync, removed);

      phase = 'Sync completed successfully.';
      progress = 1;
      notifyListeners();

      return SyncOutcome.done;
    } catch (error, stackTrace) {
      debugPrint('SyncService error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (error is ApiException && error.statusCode == 401) {
        lastError = 'This phone was signed out. Sign in again.';
      } else if (error is ApiException) {
        lastError = error.toString();
      } else {
        lastError = error.toString();
      }

      return SyncOutcome.failed;
    } finally {
      _syncing = false;
      phase = '';
      progress = null;
      notifyListeners();
    }
  }

  /// Reminders are maintained by the operating system, not the database.
  ///
  /// A reminder failure must not turn an otherwise successful sync
  /// into a failed sync.
  Future<void> _fixReminders(Set<String> resync, Set<String> removed) async {
    try {
      final notifications = NotificationService.instance;

      for (final id in removed) {
        await notifications.cancelTaskNotification(id);
        await notifications.cancelTaskAlarm(id);
      }

      if (resync.isEmpty) return;

      final bundles = await AppDatabase.instance.getAllTodosWithSubtasks();

      for (final bundle in bundles) {
        if (!resync.contains(bundle.todo.id)) continue;

        final task = TodoTask.fromBundle(bundle);
        final live = task.dueDate != null && !task.isDone;

        if (task.notificationEnabled && live) {
          await notifications.scheduleTaskNotification(task);
        } else {
          await notifications.cancelTaskNotification(task.id);
        }

        if (task.alarmEnabled && live) {
          await notifications.scheduleTaskAlarm(task);
        } else {
          await notifications.cancelTaskAlarm(task.id);
        }
      }
    } catch (error) {
      debugPrint('SyncService: reminders not updated: $error');
    }
  }
}
