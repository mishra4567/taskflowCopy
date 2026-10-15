// services/backup_service
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'package:taskflow/data/app_database.dart';
import 'package:taskflow/models/todo_task.dart';
import 'contacts_backup.dart';
import 'package:taskflow/services/notification_service.dart';
import 'restore_extension_records.dart';
import 'package:taskflow/services/todo_refresh_bus.dart';

/// Thrown with a message that is safe to show the person as-is.
class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// What a restore actually did, for the "Restored ..." message.
class RestoreResult {
  const RestoreResult({
    required this.tasks,
    required this.subtasks,
    required this.contacts,
    required this.otherItems,
    required this.skipped,
  });

  final int tasks;
  final int subtasks;
  final int contacts;
  final int otherItems;

  /// Entries in the file that couldn't be used (missing id/title, a
  /// subtask whose task isn't in the file, ...).
  final int skipped;

  String get summary {
    final parts = <String>[
      if (tasks > 0) '$tasks ${tasks == 1 ? 'task' : 'tasks'}',
      if (subtasks > 0) '$subtasks ${subtasks == 1 ? 'subtask' : 'subtasks'}',
      if (contacts > 0) '$contacts ${contacts == 1 ? 'contact' : 'contacts'}',
      if (otherItems > 0)
        '$otherItems other ${otherItems == 1 ? 'item' : 'items'}',
    ];
    final main = parts.isEmpty
        ? 'Nothing new to restore'
        : 'Restored ${parts.join(', ')}';
    return skipped > 0 ? '$main ($skipped unreadable skipped)' : main;
  }
}

/// Backs up and restores tasks (with subtasks) and contacts, plus any
/// other extension records, as one .zip holding taskflow_backup.json.
///
/// Works on bytes only — [createBackup] returns the zip's bytes and
/// [restore] takes them — so it doesn't care how the file gets saved,
/// shared or picked; keep using whatever the Settings backup card
/// already does for that part.
///
/// File format (backupFormatVersion 2; version 1 files still restore):
/// {
///   "app": "taskflow", "backupFormatVersion": 2, "exportedAt": ISO-8601,
///   "todos":    [ {id,title,category,priority,dueDate,endDate,isDone,
///                  notificationEnabled,alarmEnabled} ],   // dates = ms
///   "subtasks": [ {todoId,title,isDone} ],
///   "contacts": [ {firstName,secondName,number,createdAt} ],
///   "extensionRecords": [ {extensionType,payload} ]       // not contacts
/// }
///
/// Restore MERGES into what's on the phone: a task in the file replaces
/// the task with the same id, everything else already on the phone is
/// left alone. The database part is one transaction, so a failure
/// part-way changes nothing.
class BackupService {
  BackupService._();

  static const fileName = 'taskflow_backup.zip';
  static const _jsonName = 'taskflow_backup.json';
  static const _formatVersion = 2;

  // ---------------------------------------------------------------- export

  static Future<Uint8List> createBackup() async {
    final db = AppDatabase.instance;

    final bundles = await db.getAllTodosWithSubtasks();
    final todos = <Map<String, dynamic>>[];
    final subtasks = <Map<String, dynamic>>[];
    for (final bundle in bundles) {
      final t = bundle.todo;
      todos.add({
        'id': t.id,
        'title': t.title,
        'category': t.category,
        'priority': t.priority,
        'dueDate': t.dueDate?.millisecondsSinceEpoch,
        'endDate': t.endDate?.millisecondsSinceEpoch,
        'isDone': t.isDone,
        'notificationEnabled': t.notificationEnabled,
        'alarmEnabled': t.alarmEnabled,
      });
      for (final s in bundle.subtasks) {
        subtasks.add({
          'todoId': s.todoId,
          'title': s.title,
          'isDone': s.isDone,
        });
      }
    }

    // Contacts have their own table and their own key; anything of type
    // 'contacts' still lingering in extension records is left out so it
    // can't be restored twice.
    final records = await db.select(db.extensionRecords).get();
    final otherRecords = <Map<String, dynamic>>[
      for (final r in records)
        if (r.extensionType != 'contacts')
          {'extensionType': r.extensionType, 'payload': r.payload},
    ];

    final json = const JsonEncoder.withIndent('  ').convert({
      'app': 'taskflow',
      'backupFormatVersion': _formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'todos': todos,
      'subtasks': subtasks,
      'contacts': await exportContacts(),
      'extensionRecords': otherRecords,
    });

    final jsonBytes = utf8.encode(json);
    final archive = Archive()
      ..addFile(ArchiveFile(_jsonName, jsonBytes.length, jsonBytes));
    final encoded = ZipEncoder().encode(archive);
    // ignore: unnecessary_null_comparison
    if (encoded == null) throw BackupException("Couldn't create the zip.");
    return Uint8List.fromList(encoded);
  }

  // --------------------------------------------------------------- restore

  /// [bytes] is the picked file: the .zip, or a bare .json.
  static Future<RestoreResult> restore(Uint8List bytes) async {
    final data = _decode(bytes);

    final version = data['backupFormatVersion'];
    if (version is int && version > _formatVersion) {
      throw BackupException(
        'This backup was made by a newer version of TaskFlow. '
        'Update the app and try again.',
      );
    }
    if (!data.containsKey('todos') &&
        !data.containsKey('contacts') &&
        !data.containsKey('extensionRecords')) {
      throw BackupException("That file doesn't look like a TaskFlow backup.");
    }

    final db = AppDatabase.instance;
    var taskCount = 0;
    var subtaskCount = 0;
    var skipped = 0;
    var contactCount = 0;
    var otherCount = 0;
    final restoredIds = <String>{};

    try {
      await db.transaction(() async {
        final subtaskEntries = _maps(data['subtasks']).toList();
        final subtasksByTodo = <String, List<Map>>{};
        for (final s in subtaskEntries) {
          final todoId = s['todoId'];
          if (todoId is String) (subtasksByTodo[todoId] ??= []).add(s);
        }

        for (final raw in _maps(data['todos'])) {
          final id = raw['id'];
          final title = raw['title'];
          if (id is! String || id.isEmpty || title is! String) {
            skipped++;
            continue;
          }

          final category = raw['category'];
          final priority = raw['priority'];
          await db.upsertTodo(
            TodosCompanion.insert(
              id: id,
              title: title,
              category: category is String && category.trim().isNotEmpty
                  ? category.trim()
                  : 'General',
              priority: TaskPriority.values.any((p) => p.name == priority)
                  ? priority as String
                  : TaskPriority.medium.name,
              dueDate: Value(_date(raw['dueDate'])),
              endDate: Value(_date(raw['endDate'])),
              isDone: Value(raw['isDone'] == true),
              notificationEnabled: Value(raw['notificationEnabled'] == true),
              alarmEnabled: Value(raw['alarmEnabled'] == true),
            ),
          );

          // Replace this task's subtasks with the backed-up ones (none
          // is a valid backup state too: it clears any local ones).
          final subs = [
            for (final s in subtasksByTodo[id] ?? const <Map>[])
              if (s['title'] is String)
                SubtasksCompanion.insert(
                  todoId: id,
                  title: s['title'] as String,
                  isDone: Value(s['isDone'] == true),
                ),
          ];
          await db.replaceSubtasksForTodo(id, subs);

          restoredIds.add(id);
          taskCount++;
          subtaskCount += subs.length;
        }

        // Subtasks whose task isn't in the file can't be attached to
        // anything — count them rather than lose track silently.
        final attached = subtasksByTodo.entries
            .where((e) => restoredIds.contains(e.key))
            .fold<int>(0, (sum, e) => sum + e.value.length);
        skipped += subtaskEntries.length - attached;

        contactCount = await restoreContacts(data);
        otherCount = await restoreExtensionRecords(data['extensionRecords']);
      });
    } catch (e) {
      debugPrint('BackupService.restore failed: $e');
      throw BackupException("Restore failed, nothing was changed. ($e)");
    }

    // The database part is done and committed. Reminders live in the OS,
    // not the database, so restored tasks need them scheduled again — and
    // a problem here (e.g. notification permission off) must not turn a
    // successful restore into a reported failure.
    TodoRefreshBus.notify();
    try {
      await _resyncReminders(restoredIds);
    } catch (e) {
      debugPrint('BackupService: reminders not rescheduled: $e');
    }

    return RestoreResult(
      tasks: taskCount,
      subtasks: subtaskCount,
      contacts: contactCount,
      otherItems: otherCount,
      skipped: skipped,
    );
  }

  // ------------------------------------------------ save & pick (the UI)

  /// "Back up now": builds the backup and asks where to save it. Returns
  /// the saved location to show the person, or null if they cancelled
  /// the save dialog.
  static Future<String?> exportToZip() async {
    final bytes = await createBackup();
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save TaskFlow backup',
      fileName: fileName,
      bytes: bytes,
    );
    return _asLocation(saved);
  }

  /// "Restore": asks for a backup file (.zip, or a bare .json) and
  /// restores it. Returns null if they cancelled the picker; throws
  /// [BackupException] (message safe to show) if the file can't be used.
  static Future<RestoreResult?> pickAndRestore() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw BackupException("Couldn't read the file you picked.");
    }
    return restore(bytes);
  }

  /// saveFile has returned both a path String and a Uri across
  /// file_picker versions; either becomes something displayable.
  static String? _asLocation(Object? saved) {
    if (saved == null) return null;
    if (saved is Uri) {
      return saved.scheme == 'file' ? saved.toFilePath() : saved.toString();
    }
    return saved.toString();
  }

  // --------------------------------------------------------------- helpers

  static Future<void> _resyncReminders(Set<String> ids) async {
    if (ids.isEmpty) return;
    final notifications = NotificationService.instance;
    final bundles = await AppDatabase.instance.getAllTodosWithSubtasks();
    for (final bundle in bundles) {
      if (!ids.contains(bundle.todo.id)) continue;
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
  }

  static Map<String, dynamic> _decode(Uint8List bytes) {
    String text;
    final isZip = bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    try {
      if (isZip) {
        final files = ZipDecoder()
            .decodeBytes(bytes)
            .files
            .where((f) => f.isFile)
            .toList();
        final entry = files.firstWhere(
          (f) => f.name.split('/').last == _jsonName,
          orElse: () => files.firstWhere(
            (f) => f.name.toLowerCase().endsWith('.json'),
            orElse: () => throw BackupException(
              'No taskflow_backup.json inside that zip.',
            ),
          ),
        );
        text = utf8.decode(entry.content as List<int>);
      } else {
        text = utf8.decode(bytes);
      }
    } on BackupException {
      rethrow;
    } catch (_) {
      throw BackupException("Couldn't read that file as a backup.");
    }

    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw BackupException(
        'The backup file is damaged (its JSON is invalid).',
      );
    }
    if (decoded is! Map) {
      throw BackupException("That file doesn't look like a TaskFlow backup.");
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Iterable<Map> _maps(Object? value) =>
      value is List ? value.whereType<Map>() : const <Map>[];

  static DateTime? _date(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
