// services/contacts_backup
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/app_database.dart';

/// Contacts as plain maps, for the backup JSON's top-level `contacts`
/// key. Add it where the export builds its map:
///
///   'contacts': await exportContacts(),
///
/// (createdAt is milliseconds since epoch, the same as every other date
/// in the backup file.)
Future<List<Map<String, dynamic>>> exportContacts() async {
  final all = await AppDatabase.instance.getAllContacts();
  return [
    for (final c in all)
      {
        'firstName': c.firstName,
        'secondName': c.secondName,
        'number': c.number,
        'createdAt': c.createdAt.millisecondsSinceEpoch,
      },
  ];
}

typedef _Incoming = ({
  String firstName,
  String secondName,
  String number,
  DateTime? createdAt,
});

String _text(Object? value) => value == null ? '' : '$value'.trim();

DateTime? _date(Object? value) =>
    value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;

/// Restores contacts from a decoded taskflow_backup.json ([backup] is the
/// whole map). Reads two places, so both new and old backups work:
/// - `contacts`: the current format, written by [exportContacts].
/// - `extensionRecords` entries of type 'contacts': how backups made
///   before contacts got their own table stored them (payload is a JSON
///   string with firstName / secondName / number).
///
/// A contact that already exists (same first name, second name and
/// number) is skipped, so restoring the same backup twice doesn't
/// duplicate everyone. Returns how many were added, and prints one
/// summary line to the debug console.
Future<int> restoreContacts(Map<dynamic, dynamic> backup) async {
  final incoming = <_Incoming>[];

  final current = backup['contacts'];
  if (current is List) {
    for (final item in current) {
      if (item is! Map) continue;
      incoming.add((
        firstName: _text(item['firstName']),
        secondName: _text(item['secondName']),
        number: _text(item['number']),
        createdAt: _date(item['createdAt']),
      ));
    }
  }

  final legacy = backup['extensionRecords'];
  if (legacy is List) {
    for (final item in legacy) {
      if (item is! Map || item['extensionType'] != 'contacts') continue;
      final rawPayload = item['payload'];
      Object? decoded;
      try {
        decoded = rawPayload is String ? jsonDecode(rawPayload) : rawPayload;
      } catch (_) {
        continue;
      }
      if (decoded is! Map) continue;
      incoming.add((
        firstName: _text(decoded['firstName']),
        secondName: _text(decoded['secondName']),
        number: _text(decoded['number']),
        createdAt: _date(item['createdAt']),
      ));
    }
  }

  final db = AppDatabase.instance;
  String keyOf(String first, String second, String number) =>
      '${first.toLowerCase()}|${second.toLowerCase()}|$number';

  final seen = {
    for (final c in await db.getAllContacts())
      keyOf(c.firstName.trim(), c.secondName.trim(), c.number.trim()),
  };

  var added = 0;
  var alreadyPresent = 0;
  var empty = 0;
  for (final c in incoming) {
    if (c.firstName.isEmpty && c.secondName.isEmpty && c.number.isEmpty) {
      empty++;
      continue;
    }
    final key = keyOf(c.firstName, c.secondName, c.number);
    if (!seen.add(key)) {
      alreadyPresent++;
      continue;
    }
    await db.addContact(
      firstName: c.firstName,
      secondName: c.secondName,
      number: c.number,
      createdAt: c.createdAt,
    );
    added++;
  }

  debugPrint(
    'restoreContacts: ${incoming.length} in backup, $added added, '
    '$alreadyPresent already present, $empty empty.',
  );
  return added;
}
