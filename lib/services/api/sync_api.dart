import '../api/api_client.dart';

/// Internal representation of a change.
///
/// This is NOT the Laravel wire format. SyncLocalStore converts this
/// object into Laravel's grouped snake_case format before pushing.
class SyncRecord {
  const SyncRecord({
    required this.kind,
    required this.uuid,
    required this.updatedAt,
    this.deleted = false,
    this.payload,
    this.serverVersion,
  });

  final String kind;
  final String uuid;
  final DateTime updatedAt;
  final bool deleted;
  final Map<String, dynamic>? payload;
  final int? serverVersion;

  /// Parse one record from Laravel's grouped pull response.
  ///
  /// Laravel sends dates as ISO-8601 strings and uses snake_case keys.
  static SyncRecord? fromLaravelJson(String kind, Object? raw) {
    if (raw is! Map) return null;

    final row = Map<String, dynamic>.from(raw);
    final id = row['id'];
    final updatedAt = _parseDate(row['client_updated_at']);

    if (id is! String || id.trim().isEmpty || updatedAt == null) {
      return null;
    }

    final deleted = row['purged_at'] != null;
    final payload = <String, dynamic>{};

    switch (kind) {
      case 'task':
        payload.addAll({
          'title': row['title'],
          'category': row['category'],
          'priority': row['priority'],
          'dueDate': _dateToMs(row['due_date']),
          'endDate': _dateToMs(row['end_date']),
          'isDone': row['is_done'],
          'notificationEnabled': row['notification_enabled'],
          'alarmEnabled': row['alarm_enabled'],
          'completedAt': _dateToMs(row['completed_at']),
          'archivedAt': _dateToMs(row['archived_at']),
          'deletedAt': _dateToMs(row['deleted_at']),
          'subtasks': row['subtasks'],
        });
        break;

      case 'contact':
        payload.addAll({
          'name': row['name'],
          'numberEncrypted': row['number_encrypted'],
          'countryCode': row['country_code'],
        });
        break;

      case 'expense':
        payload.addAll({
          'amountPaise': row['amount_paise'],
          'paidAt': _dateToMs(row['paid_at']),
          'payee': row['payee'],
          'category': row['category'],
          'note': row['note'],
          'method': row['method'],
          'upiRef': row['upi_ref'],
          'source': row['source'],
          'direction': row['direction'],
          'createdAt': _dateToMs(row['client_created_at']),
        });
        break;

      default:
        return null;
    }

    return SyncRecord(
      kind: kind,
      uuid: id,
      updatedAt: updatedAt,
      deleted: deleted,
      payload: payload,
      serverVersion: row['server_version'] is num
          ? (row['server_version'] as num).toInt()
          : null,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) return value.toLocal();

    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.toInt(),
        isUtc: true,
      ).toLocal();
    }

    return null;
  }

  static int? _dateToMs(Object? value) {
    return _parseDate(value)?.millisecondsSinceEpoch;
  }
}

class SyncPage {
  const SyncPage({
    required this.records,
    required this.cursor,
    required this.hasMore,
    required this.skipped,
  });

  final List<SyncRecord> records;

  /// Laravel's integer server cursor.
  final int cursor;

  final bool hasMore;
  final int skipped;
}

class SyncApi {
  SyncApi._();

  static final SyncApi instance = SyncApi._();

  final ApiClient _client = ApiClient.instance;

  /// POST /api/v1/sync/push
  ///
  /// Expected body:
  /// {
  ///   "changes": {
  ///     "tasks": [],
  ///     "contacts": [],
  ///     "expenses": []
  ///   }
  /// }
  Future<Map<String, dynamic>> push(
    Map<String, List<Map<String, dynamic>>> changes,
  ) async {
    final response = await _client.send(
      'POST',
      'sync/push',
      auth: true,
      body: {
        'changes': {
          'tasks': changes['tasks'] ?? [],
          'contacts': changes['contacts'] ?? [],
          'expenses': changes['expenses'] ?? [],
        },
      },
    );

    return response.data;
  }

  /// GET /api/v1/sync/pull?cursor=0&limit=500
  ///
  /// Expected response:
  /// {
  ///   "cursor": 3,
  ///   "has_more": false,
  ///   "changes": {
  ///     "tasks": [],
  ///     "contacts": [],
  ///     "expenses": []
  ///   }
  /// }
  Future<SyncPage> pull(int cursor, {int limit = 500}) async {
    final response = await _client.send(
      'GET',
      'sync/pull?cursor=$cursor&limit=$limit',
      auth: true,
    );

    final data = response.data;
    final rawChanges = data['changes'];

    if (rawChanges is! Map) {
      throw const FormatException(
        'Invalid sync response: changes must be an object.',
      );
    }

    final records = <SyncRecord>[];
    var skipped = 0;

    for (final kind in ['tasks', 'contacts', 'expenses']) {
      final rawRows = rawChanges[kind];

      if (rawRows == null) continue;

      if (rawRows is! List) {
        throw FormatException('Invalid sync response: $kind must be an array.');
      }

      final singularKind = switch (kind) {
        'tasks' => 'task',
        'contacts' => 'contact',
        'expenses' => 'expense',
        _ => '',
      };

      for (final row in rawRows) {
        final record = SyncRecord.fromLaravelJson(singularKind, row);

        if (record == null) {
          skipped++;
        } else {
          records.add(record);
        }
      }
    }

    final rawCursor = data['cursor'];
    if (rawCursor is! num) {
      throw const FormatException(
        'Invalid sync response: cursor must be an integer.',
      );
    }

    return SyncPage(
      records: records,
      cursor: rawCursor.toInt(),
      hasMore: data['has_more'] == true,
      skipped: skipped,
    );
  }
}
