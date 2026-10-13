// services/restore_extension_records
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/app_database.dart';

/// Restores the `extensionRecords` list from a taskflow_backup.json —
/// this is where saved contacts live (extensionType 'contacts', one row
/// per contact, payload = a JSON string like
/// {"number":"...","firstName":"...","secondName":"..."}).
///
/// [raw] is `data['extensionRecords']` from the decoded backup. Returns
/// how many records were actually added, so the caller can show
/// "Restored 14 tasks and 2 contacts".
///
/// Deliberately uses only AppDatabase.getExtensionRecords /
/// addExtensionRecord — the same two calls the Contacts screen already
/// uses to read and save a contact — instead of inserting rows with
/// their backed-up ids:
/// - A fresh row id is assigned, so restoring onto a phone that already
///   has rows 1 and 2 can't fail with a primary-key conflict.
/// - A record whose type + payload already exists is skipped, so
///   restoring the same backup twice doesn't duplicate every contact.
/// The one thing not carried over is each record's original createdAt;
/// restored contacts are stamped with the restore time.
///
/// Prints one summary line to the debug console saying exactly what
/// happened to every record (added / already present / unreadable), so
/// "restored 0" is never ambiguous.
Future<int> restoreExtensionRecords(Object? raw) async {
  if (raw is! List) {
    debugPrint(
      'restoreExtensionRecords: expected a list, got ${raw.runtimeType}',
    );
    return 0;
  }

  final db = AppDatabase.instance;
  final existingByType = <String, Set<String>>{};
  var added = 0;
  var alreadyPresent = 0;
  var unreadable = 0;
  var skippedContacts = 0;

  for (final item in raw) {
    if (item is! Map) {
      unreadable++;
      continue;
    }
    final type = item['extensionType'];
    if (type is! String || type.isEmpty) {
      unreadable++;
      continue;
    }
    // Contacts have their own table now (see restoreContacts in
    // contacts_backup.dart) — putting them back here as extension
    // records would re-create exactly what was just migrated away.
    if (type == 'contacts') {
      skippedContacts++;
      continue;
    }

    // The export writes payload as a JSON string; accept an already-
    // decoded map too, in case a future export format changes that.
    final rawPayload = item['payload'];
    final payload = rawPayload is String
        ? rawPayload
        : rawPayload is Map
        ? jsonEncode(rawPayload)
        : null;
    if (payload == null) {
      unreadable++;
      continue;
    }

    final seen = existingByType[type] ??= (await db.getExtensionRecords(
      type,
    )).map((r) => r.payload).toSet();
    if (seen.contains(payload)) {
      alreadyPresent++;
      continue;
    }

    await db.addExtensionRecord(type, payload);
    seen.add(payload);
    added++;
  }

  final inDatabase = {
    for (final entry in existingByType.entries) entry.key: entry.value.length,
  };
  debugPrint(
    'restoreExtensionRecords: ${raw.length} in backup, $added added, '
    '$alreadyPresent already present, $unreadable unreadable, '
    '$skippedContacts contacts left to restoreContacts. '
    'Distinct records now in the database, by type: $inDatabase',
  );
  return added;
}
