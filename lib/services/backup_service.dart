// services/backup_service
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';

/// Result of [BackupService.importFromZip] — how many tasks were
/// actually added vs. left alone because a task with that id already
/// existed. [cancelled] is true only when the user backed out of the
/// file picker, distinct from "picked a zip with 0 new tasks in it".
class RestoreSummary {
  const RestoreSummary({
    this.todosAdded = 0,
    this.todosSkipped = 0,
    this.cancelled = false,
  });

  final int todosAdded;
  final int todosSkipped;
  final bool cancelled;
}

/// Exports the app's data to a single JSON file, then wraps that JSON in
/// a .zip — the zip is what actually gets saved/shared; the JSON is
/// just its one entry inside. Offline only: nothing here talks to any
/// server, it just writes a file the user chooses a location for.
///
/// Uses Drift's own generated toJson() on each table row rather than a
/// hand-written shape, so adding a column later doesn't silently leave
/// it out of backups — only restoring an *older* backup file (not built
/// yet) would need to handle a shape that predates a given column.
class BackupService {
  BackupService._();

  /// Version of the backup file's own JSON shape — bump this if the
  /// structure below ever changes in a way a future restore needs to
  /// branch on. Independent of AppDatabase.schemaVersion.
  static const _backupFormatVersion = 1;

  /// Builds the backup JSON, zips it, and opens the system "save as"
  /// dialog so the user picks where it goes. Returns the saved
  /// location (a path, on mobile/desktop) or null if they cancelled.
  static Future<String?> exportToZip() async {
    final jsonBytes = await _buildBackupJsonBytes();

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final jsonFile = File('${tempDir.path}/taskflow_backup.json');
    await jsonFile.writeAsBytes(jsonBytes);

    final zipFileName = 'taskflow_backup_$timestamp.zip';
    final zipPath = '${tempDir.path}/$zipFileName';

    // ZipFileEncoder (archive_io.dart) writes straight to disk via
    // dart:io rather than building an in-memory Archive/ZipEncoder by
    // hand — simplest, most stable surface of the archive package for
    // "just zip this one file" (archive 4.x).
    final zipEncoder = ZipFileEncoder();
    zipEncoder.create(zipPath);
    await zipEncoder.addFile(jsonFile);
    await zipEncoder.close();

    final zipFile = File(zipPath);
    final zipBytes = await zipFile.readAsBytes();

    // file_picker 12+ requires both fileName and bytes for saveFile —
    // it writes them wherever the user picks, which on mobile is the
    // only way to get a file out of app-private storage and somewhere
    // the user can actually find/share it.
    final result = await FilePicker.saveFile(
      fileName: zipFileName,
      bytes: zipBytes,
      dialogTitle: 'Save TaskFlow backup',
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    // The temp copies only existed to get bytes into the picker call
    // above — clean them up rather than leaving them in the cache dir.
    unawaited(jsonFile.delete().catchError((_) => jsonFile));
    unawaited(zipFile.delete().catchError((_) => zipFile));

    return result?.toString();
  }

  /// Lets the user pick a .zip backup and merges its tasks into the
  /// current database. Policy: a task whose id already exists is left
  /// completely alone (not overwritten) — only tasks that are actually
  /// new get inserted, along with their own subtasks. Nothing currently
  /// in the app is ever deleted or modified by a restore.
  ///
  /// Extensions/ExtensionRecords aren't restored yet — their table
  /// field names aren't confirmed here the way Todos/Subtasks' are
  /// (both already used successfully elsewhere in this codebase), and
  /// guessing wrong risks silently mis-inserting data.
  static Future<RestoreSummary> importFromZip() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (file == null || file.path == null) {
      return const RestoreSummary(cancelled: true);
    }

    final zipBytes = await File(file.path!).readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);

    ArchiveFile? jsonEntry;
    for (final entry in archive) {
      if (entry.isFile && entry.name.toLowerCase().endsWith('.json')) {
        jsonEntry = entry;
        break;
      }
    }
    if (jsonEntry == null) {
      throw const FormatException('No JSON file found inside that zip.');
    }

    final jsonBytes = jsonEntry.readBytes();
    if (jsonBytes == null) {
      throw const FormatException(
        'Could not read the backup file inside that zip.',
      );
    }
    final jsonString = utf8.decode(jsonBytes);
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    final db = AppDatabase.instance;
    final todosJson = ((data['todos'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final subtasksJson = ((data['subtasks'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    var todosAdded = 0;
    var todosSkipped = 0;

    await db.transaction(() async {
      for (final map in todosJson) {
        final id = map['id'] as String;

        final exists = await (db.select(
          db.todos,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (exists != null) {
          todosSkipped++;
          continue;
        }

        await db
            .into(db.todos)
            .insert(
              TodosCompanion.insert(
                id: id,
                title: map['title'] as String,
                category: map['category'] as String,
                priority: map['priority'] as String,
                dueDate: Value(_msToDate(map['dueDate'])),
                endDate: Value(_msToDate(map['endDate'])),
                isDone: Value(map['isDone'] as bool? ?? false),
                notificationEnabled: Value(
                  map['notificationEnabled'] as bool? ?? false,
                ),
                alarmEnabled: Value(map['alarmEnabled'] as bool? ?? false),
              ),
            );
        todosAdded++;

        // Only this newly-added task's own subtasks come along — an
        // existing task's current subtasks are never touched.
        for (final s in subtasksJson.where((s) => s['todoId'] == id)) {
          await db
              .into(db.subtasks)
              .insert(
                SubtasksCompanion.insert(
                  todoId: id,
                  title: s['title'] as String,
                  isDone: Value(s['isDone'] as bool? ?? false),
                ),
              );
        }
      }
    });

    return RestoreSummary(todosAdded: todosAdded, todosSkipped: todosSkipped);
  }

  static DateTime? _msToDate(dynamic ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);

  static Future<Uint8List> _buildBackupJsonBytes() async {
    final db = AppDatabase.instance;
    final todos = await db.select(db.todos).get();
    final subtasks = await db.select(db.subtasks).get();
    final extensions = await db.select(db.extensions).get();
    final extensionRecords = await db.select(db.extensionRecords).get();

    final data = {
      'app': 'taskflow',
      'backupFormatVersion': _backupFormatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'todos': todos.map((t) => t.toJson()).toList(),
      'subtasks': subtasks.map((s) => s.toJson()).toList(),
      'extensions': extensions.map((e) => e.toJson()).toList(),
      'extensionRecords': extensionRecords.map((r) => r.toJson()).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(data);
    return Uint8List.fromList(utf8.encode(jsonString));
  }
}
