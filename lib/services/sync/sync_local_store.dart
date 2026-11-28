import 'package:drift/drift.dart';
import 'package:taskflow/data/app_database.dart';
import 'package:taskflow/services/api/sync_api.dart';
import 'package:taskflow/services/encryption/feature_key_service.dart';

class ApplyResult {
  const ApplyResult({
    this.tasks = 0,
    this.expenses = 0,
    this.contacts = 0,
    this.skipped = 0,
    this.tasksToResync = const {},
    this.tasksRemoved = const {},
  });

  final int tasks;
  final int expenses;
  final int contacts;
  final int skipped;

  final Set<String> tasksToResync;
  final Set<String> tasksRemoved;
}

class SyncLocalStore {
  SyncLocalStore._();

  static const _priorities = {'low', 'medium', 'high'};

  static DateTime? _ms(Object? value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed.toLocal();

      final numeric = num.tryParse(value);
      if (numeric != null) {
        return DateTime.fromMillisecondsSinceEpoch(numeric.toInt());
      }
    }

    return null;
  }

  static String? _isoFromMs(Object? value) {
    final date = _ms(value);
    return date?.toUtc().toIso8601String();
  }

  static String _iso(DateTime date) => date.toUtc().toIso8601String();

  // -----------------------------------------------------------------------
  // PUSH: collect local changes
  // -----------------------------------------------------------------------

  static Future<List<SyncRecord>> collectChanges(DateTime since) async {
    final db = AppDatabase.instance;
    final out = <SyncRecord>[];

    // Tasks.
    final tasks = await (db.select(
      db.todos,
    )..where((t) => t.updatedAt.isBiggerOrEqualValue(since))).get();

    for (final task in tasks) {
      final subtasks = await (db.select(
        db.subtasks,
      )..where((s) => s.todoId.equals(task.id))).get();

      out.add(
        SyncRecord(
          kind: 'task',
          uuid: task.id,
          updatedAt: task.updatedAt,
          payload: {
            'title': task.title,
            'category': task.category,
            'priority': task.priority,
            'dueDate': task.dueDate?.millisecondsSinceEpoch,
            'endDate': task.endDate?.millisecondsSinceEpoch,
            'isDone': task.isDone,
            'notificationEnabled': task.notificationEnabled,
            'alarmEnabled': task.alarmEnabled,
            'completedAt': task.completedAt?.millisecondsSinceEpoch,
            'archivedAt': task.archivedAt?.millisecondsSinceEpoch,
            'deletedAt': task.deletedAt?.millisecondsSinceEpoch,
            'subtasks': [
              for (final subtask in subtasks)
                {'title': subtask.title, 'isDone': subtask.isDone},
            ],
          },
        ),
      );
    }

    // Contacts.
    final contacts = await (db.select(
      db.contacts,
    )..where((c) => c.updatedAt.isBiggerOrEqualValue(since))).get();

    for (final contact in contacts) {
      final uuid = contact.uuid;
      if (uuid == null || uuid.isEmpty) continue;

      out.add(
        SyncRecord(
          kind: 'contact',
          uuid: uuid,
          updatedAt: contact.updatedAt,
          payload: {
            'firstName': contact.firstName,
            'secondName': contact.secondName,
            'number': contact.number,
          },
        ),
      );
    }

    // Expenses.
    final expenses = await (db.select(
      db.expenses,
    )..where((e) => e.updatedAt.isBiggerOrEqualValue(since))).get();

    for (final expense in expenses) {
      final uuid = expense.uuid;
      if (uuid == null || uuid.isEmpty) continue;

      out.add(
        SyncRecord(
          kind: 'expense',
          uuid: uuid,
          updatedAt: expense.updatedAt,
          payload: {
            'amountPaise': expense.amountPaise,
            'paidAt': expense.paidAt.millisecondsSinceEpoch,
            'payee': expense.payee,
            'category': expense.category,
            'note': expense.note,
            'method': expense.method,
            'upiRef': expense.upiRef,
            'source': expense.source,
            'direction': expense.direction,
            'createdAt': expense.createdAt.millisecondsSinceEpoch,
          },
        ),
      );
    }

    // Permanent-deletion tombstones.
    final tombstones = await (db.select(
      db.syncTombstones,
    )..where((t) => t.deletedAt.isBiggerOrEqualValue(since))).get();

    for (final tombstone in tombstones) {
      out.add(
        SyncRecord(
          kind: tombstone.kind,
          uuid: tombstone.uuid,
          updatedAt: tombstone.deletedAt,
          deleted: true,
        ),
      );
    }

    return out;
  }

  // -----------------------------------------------------------------------
  // PUSH: convert to Laravel's exact grouped request format
  // -----------------------------------------------------------------------

  static Future<Map<String, List<Map<String, dynamic>>>> toLaravelChanges(
    List<SyncRecord> records,
  ) async {
    final changes = <String, List<Map<String, dynamic>>>{
      'tasks': [],
      'contacts': [],
      'expenses': [],
    };

    final featureKeys = FeatureKeyService.instance;

    for (final record in records) {
      final payload = record.payload ?? {};

      switch (record.kind) {
        case 'task':
          if (record.deleted) {
            changes['tasks']!.add({
              'id': record.uuid,
              'purged_at': _iso(record.updatedAt),
              'client_updated_at': _iso(record.updatedAt),
            });
            break;
          }

          final rawSubtasks = payload['subtasks'];
          final subtasks = rawSubtasks is List && rawSubtasks.isNotEmpty
              ? rawSubtasks
              : null;

          changes['tasks']!.add({
            'id': record.uuid,
            'title': payload['title'],
            'category': payload['category'],
            'priority': payload['priority'],
            'due_date': _isoFromMs(payload['dueDate']),
            'end_date': _isoFromMs(payload['endDate']),
            'is_done': payload['isDone'] == true,
            'notification_enabled': payload['notificationEnabled'] == true,
            'alarm_enabled': payload['alarmEnabled'] == true,
            'completed_at': _isoFromMs(payload['completedAt']),
            'archived_at': _isoFromMs(payload['archivedAt']),
            'deleted_at': _isoFromMs(payload['deletedAt']),
            'purged_at': null,
            'subtasks': subtasks,
            'client_updated_at': _iso(record.updatedAt),
          });
          break;

        case 'contact':
          if (record.deleted) {
            changes['contacts']!.add({
              'id': record.uuid,
              'purged_at': _iso(record.updatedAt),
              'client_updated_at': _iso(record.updatedAt),
            });
            break;
          }

          final firstName = payload['firstName'] is String
              ? (payload['firstName'] as String).trim()
              : '';
          final secondName = payload['secondName'] is String
              ? (payload['secondName'] as String).trim()
              : '';
          final number = payload['number'] is String
              ? (payload['number'] as String).trim()
              : '';

          final name = [
            firstName,
            secondName,
          ].where((part) => part.isNotEmpty).join(' ');

          String? encryptedNumber;

          if (number.isNotEmpty) {
            final cipher = await featureKeys.encryptField(
              EncryptedFeature.contacts,
              number,
              recordId: record.uuid,
            );

            encryptedNumber = 'v1:$cipher';
          }

          changes['contacts']!.add({
            'id': record.uuid,
            'name': name,
            'number_encrypted': encryptedNumber,
            'purged_at': null,
            'client_updated_at': _iso(record.updatedAt),
            'country_code': null,
          });
          break;

        case 'expense':
          if (record.deleted) {
            changes['expenses']!.add({
              'id': record.uuid,
              'purged_at': _iso(record.updatedAt),
              'client_updated_at': _iso(record.updatedAt),
            });
            break;
          }

          changes['expenses']!.add({
            'id': record.uuid,
            'amount_paise': payload['amountPaise'],
            'paid_at': _isoFromMs(payload['paidAt']),
            'payee': payload['payee'],
            'category': payload['category'],
            'note': payload['note'],
            'method': payload['method'],
            'upi_ref': payload['upiRef'],
            'source': payload['source'],
            'direction': payload['direction'],
            'client_created_at': _isoFromMs(payload['createdAt']),
            'purged_at': null,
            'client_updated_at': _iso(record.updatedAt),
          });
          break;
      }
    }

    return changes;
  }

  // -----------------------------------------------------------------------
  // PULL: apply a Laravel page in one local transaction
  // -----------------------------------------------------------------------

  static Future<ApplyResult> apply(List<SyncRecord> records) async {
    final db = AppDatabase.instance;

    var tasks = 0;
    var expenses = 0;
    var contacts = 0;
    var skipped = 0;

    final resync = <String>{};
    final removed = <String>{};

    await db.transaction(() async {
      for (final record in records) {
        switch (record.kind) {
          case 'task':
            final outcome = await _applyTask(db, record);

            if (outcome == _Outcome.skipped) skipped++;

            if (outcome == _Outcome.written) {
              tasks++;
              resync.add(record.uuid);
            }

            if (outcome == _Outcome.removed) {
              tasks++;
              removed.add(record.uuid);
            }
            break;

          case 'contact':
            final outcome = await _applyContact(db, record);

            if (outcome == _Outcome.skipped) skipped++;

            if (outcome == _Outcome.written || outcome == _Outcome.removed) {
              contacts++;
            }
            break;

          case 'expense':
            final outcome = await _applyExpense(db, record);

            if (outcome == _Outcome.skipped) skipped++;

            if (outcome == _Outcome.written || outcome == _Outcome.removed) {
              expenses++;
            }
            break;

          default:
            skipped++;
        }
      }
    });

    return ApplyResult(
      tasks: tasks,
      expenses: expenses,
      contacts: contacts,
      skipped: skipped,
      tasksToResync: resync,
      tasksRemoved: removed,
    );
  }

  static Future<void> _clearTombstone(
    AppDatabase db,
    String kind,
    String uuid,
  ) async {
    await (db.delete(
      db.syncTombstones,
    )..where((t) => t.kind.equals(kind) & t.uuid.equals(uuid))).go();
  }

  // -----------------------------------------------------------------------
  // Apply task
  // -----------------------------------------------------------------------

  static Future<_Outcome> _applyTask(AppDatabase db, SyncRecord record) async {
    final existing = await (db.select(
      db.todos,
    )..where((t) => t.id.equals(record.uuid))).getSingleOrNull();

    if (existing != null && existing.updatedAt.isAfter(record.updatedAt)) {
      return _Outcome.ignored;
    }

    if (record.deleted) {
      if (existing == null) return _Outcome.ignored;

      await db.deleteTodo(record.uuid);
      await _clearTombstone(db, 'task', record.uuid);

      return _Outcome.removed;
    }

    final payload = record.payload;
    final title = payload?['title'];

    if (payload == null || title is! String || title.trim().isEmpty) {
      return _Outcome.skipped;
    }

    final category = payload['category'];
    final priority = payload['priority'];

    await db.upsertTodo(
      TodosCompanion.insert(
        id: record.uuid,
        title: title,
        category: category is String && category.trim().isNotEmpty
            ? category.trim()
            : 'General',
        priority: priority is String && _priorities.contains(priority)
            ? priority
            : 'medium',
        dueDate: Value(_ms(payload['dueDate'])),
        endDate: Value(_ms(payload['endDate'])),
        isDone: Value(payload['isDone'] == true),
        notificationEnabled: Value(payload['notificationEnabled'] == true),
        alarmEnabled: Value(payload['alarmEnabled'] == true),
        completedAt: Value(_ms(payload['completedAt'])),
        archivedAt: Value(_ms(payload['archivedAt'])),
        deletedAt: Value(_ms(payload['deletedAt'])),
        updatedAt: Value(record.updatedAt),
      ),
    );

    final rawSubtasks = payload['subtasks'];

    await db.replaceSubtasksForTodo(record.uuid, [
      if (rawSubtasks is List)
        for (final subtask in rawSubtasks)
          if (subtask is Map && subtask['title'] is String)
            SubtasksCompanion.insert(
              todoId: record.uuid,
              title: subtask['title'] as String,
              isDone: Value(subtask['isDone'] == true),
            ),
    ]);

    return _Outcome.written;
  }

  // -----------------------------------------------------------------------
  // Apply contact
  // -----------------------------------------------------------------------

  static Future<_Outcome> _applyContact(
    AppDatabase db,
    SyncRecord record,
  ) async {
    final existing = await (db.select(
      db.contacts,
    )..where((c) => c.uuid.equals(record.uuid))).getSingleOrNull();

    if (existing != null && existing.updatedAt.isAfter(record.updatedAt)) {
      return _Outcome.ignored;
    }

    if (record.deleted) {
      if (existing == null) return _Outcome.ignored;

      await (db.delete(
        db.contacts,
      )..where((c) => c.id.equals(existing.id))).go();

      await _clearTombstone(db, 'contact', record.uuid);
      return _Outcome.removed;
    }

    final payload = record.payload;
    if (payload == null) return _Outcome.skipped;

    final rawName = payload['name'];
    final name = rawName is String ? rawName.trim() : '';

    final rawEncrypted = payload['numberEncrypted'];
    var number = '';

    if (rawEncrypted is String && rawEncrypted.isNotEmpty) {
      if (!rawEncrypted.startsWith('v1:')) {
        throw FormatException(
          'Unsupported contact encryption version for ${record.uuid}.',
        );
      }

      final ciphertext = rawEncrypted.substring(3);

      // Do not skip a contact when its key is unavailable. The caller
      // must not advance the pull cursor if decryption fails.
      number = await FeatureKeyService.instance.decryptField(
        EncryptedFeature.contacts,
        ciphertext,
        recordId: record.uuid,
      );
    }

    if (name.isEmpty && number.isEmpty) {
      return _Outcome.skipped;
    }

    // Laravel stores one name field. Keep it in firstName locally.
    const secondName = '';

    if (existing == null) {
      await db
          .into(db.contacts)
          .insert(
            ContactsCompanion.insert(
              uuid: Value(record.uuid),
              firstName: Value(name),
              secondName: const Value(secondName),
              number: Value(number),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(record.updatedAt),
            ),
          );
    } else {
      await (db.update(
        db.contacts,
      )..where((c) => c.id.equals(existing.id))).write(
        ContactsCompanion(
          firstName: Value(name),
          secondName: const Value(secondName),
          number: Value(number),
          updatedAt: Value(record.updatedAt),
        ),
      );
    }

    await _clearTombstone(db, 'contact', record.uuid);

    return _Outcome.written;
  }

  // -----------------------------------------------------------------------
  // Apply expense
  // -----------------------------------------------------------------------

  static Future<_Outcome> _applyExpense(
    AppDatabase db,
    SyncRecord record,
  ) async {
    final existing = await (db.select(
      db.expenses,
    )..where((e) => e.uuid.equals(record.uuid))).getSingleOrNull();

    if (existing != null && existing.updatedAt.isAfter(record.updatedAt)) {
      return _Outcome.ignored;
    }

    if (record.deleted) {
      if (existing == null) return _Outcome.ignored;

      await db.deleteExpense(existing.id);
      await _clearTombstone(db, 'expense', record.uuid);

      return _Outcome.removed;
    }

    final payload = record.payload;
    final amount = payload?['amountPaise'];
    final paidAt = _ms(payload?['paidAt']);

    if (payload == null || amount is! int || amount < 0 || paidAt == null) {
      return _Outcome.skipped;
    }

    String text(String key, String fallback) {
      final value = payload[key];
      return value is String ? value : fallback;
    }

    final rawRef = payload['upiRef'];
    final upiRef = rawRef is String && rawRef.trim().isNotEmpty
        ? rawRef.trim()
        : null;

    final source = payload['source'] == 'screenshot' ? 'screenshot' : 'manual';

    final direction = payload['direction'] == 'received' ? 'received' : 'paid';

    final createdAt = _ms(payload['createdAt']);

    if (existing == null) {
      await db.insertExpense(
        ExpensesCompanion.insert(
          amountPaise: amount,
          paidAt: paidAt,
          payee: Value(text('payee', '')),
          category: Value(text('category', 'Other')),
          note: Value(text('note', '')),
          method: Value(text('method', 'Other')),
          upiRef: Value(upiRef),
          source: Value(source),
          direction: Value(direction),
          createdAt: createdAt == null
              ? const Value.absent()
              : Value(createdAt),
          uuid: Value(record.uuid),
          updatedAt: Value(record.updatedAt),
        ),
      );
    } else {
      await db.updateExpense(
        existing.id,
        ExpensesCompanion(
          amountPaise: Value(amount),
          paidAt: Value(paidAt),
          payee: Value(text('payee', '')),
          category: Value(text('category', 'Other')),
          note: Value(text('note', '')),
          method: Value(text('method', 'Other')),
          upiRef: Value(upiRef),
          source: Value(source),
          direction: Value(direction),
          updatedAt: Value(record.updatedAt),
        ),
      );
    }

    await _clearTombstone(db, 'expense', record.uuid);

    return _Outcome.written;
  }
}

enum _Outcome { written, removed, ignored, skipped }
