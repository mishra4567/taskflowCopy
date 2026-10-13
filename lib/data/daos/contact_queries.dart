// data/daos/contact_queries.dart
import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../app_database.dart';

extension SavedContactX on SavedContact {
  /// What the list shows as the contact's name: the second name, falling
  /// back to the first name when the second is blank. Neither is
  /// guaranteed non-empty, so this can still return ''.
  String get displayName {
    final second = secondName.trim();
    return second.isNotEmpty ? second : firstName.trim();
  }
}

/// Contact queries, kept in their own file like TodoQueries.
extension ContactQueries on AppDatabase {
  /// Live list, oldest first. Emits again on every insert/delete, so a
  /// screen using it never needs a manual refresh.
  Stream<List<SavedContact>> watchContacts() {
    return (select(contacts)..orderBy([(c) => OrderingTerm.asc(c.id)])).watch();
  }

  Future<List<SavedContact>> getAllContacts() {
    return (select(contacts)..orderBy([(c) => OrderingTerm.asc(c.id)])).get();
  }

  Future<int> addContact({
    required String firstName,
    required String secondName,
    required String number,
    DateTime? createdAt,
  }) {
    return into(contacts).insert(
      ContactsCompanion.insert(
        firstName: Value(firstName),
        secondName: Value(secondName),
        number: Value(number),
        // Absent = let the column default (now) apply; only a restore
        // from a backup passes the original date.
        createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
      ),
    );
  }

  Future<void> deleteContact(int id) {
    return (delete(contacts)..where((c) => c.id.equals(id))).go();
  }

  /// One-time move of contacts that were stored as extension records
  /// (extensionType 'contacts', JSON payload) into the contacts table.
  /// Each record is deleted only after its contact was added, so a
  /// payload that can't be read is left alone instead of lost. Returns
  /// how many were moved. Safe to run more than once — after the first
  /// run there is nothing left to move.
  Future<int> migrateLegacyContacts() async {
    final legacy = await (select(
      extensionRecords,
    )..where((r) => r.extensionType.equals('contacts'))).get();

    var moved = 0;
    for (final record in legacy) {
      Object? decoded;
      try {
        decoded = jsonDecode(record.payload);
      } catch (_) {
        continue;
      }
      if (decoded is! Map) continue;

      // A fresh final, so the Map type sticks inside the closure below
      // (a promoted non-final local doesn't reliably survive into one).
      final map = decoded;
      String field(String key) => '${map[key] ?? ''}'.trim();

      await addContact(
        firstName: field('firstName'),
        secondName: field('secondName'),
        number: field('number'),
        createdAt: record.createdAt,
      );
      await (delete(
        extensionRecords,
      )..where((r) => r.id.equals(record.id))).go();
      moved++;
    }
    return moved;
  }
}
